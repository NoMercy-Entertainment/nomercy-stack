<?php

use JetBrains\PhpStorm\NoReturn;

if (!class_exists('DotEnv')) {
    require '/var/www/html/classes/DotEnv.php';
}
(new DotEnv('/var/www/.env'))->load();

class KeycloakClient
{
    private string $baseUrl;
    private string $realm;
    private string $client_id;
    private string $client_secret;
    private string $phpmyadminUrl;
    private string $query;
    private string $scope;

    public function __construct()
    {
        $this->baseUrl = getenv('KEYCLOAK_FRONTEND_URL');
        $this->realm = getenv('KEYCLOAK_REALM');
        $this->client_id = getenv('KEYCLOAK_CLIENT_ID');
        $this->client_secret = getenv('KEYCLOAK_CLIENT_SECRET');
        $this->baseUrl = "https://$this->baseUrl/realms/$this->realm/protocol/openid-connect";
        $this->phpmyadminUrl = getenv('MYSQL_SERVER_NAME');

        $this->query = $this->filtered_querystring();

        $this->scope = 'openid';
    }

    public function login(): void
    {
        if (isset($_COOKIE['refresh_token'])) {
            $this->refresh_token();
        } else if (!isset($_GET['callback'])) {
            $this->get_code();
        } else {
            $this->get_token($_GET['code'] ?? '');
        }
    }

    public function logout(): void
    {
        $this->clear_session_cookies();

        header("Location: $this->baseUrl/logout?redirect_uri=$this->phpmyadminUrl");
    }

    public function get_code(): void
    {
        $response_mode = 'query';
        $response_type = 'code';
        $nonce = uniqid(strval(rand()), true);
        $redirect = urlencode("$this->phpmyadminUrl/auth.php?callback=1");

        header("Location: $this->baseUrl/auth?client_id=$this->client_id&response_mode=$response_mode&response_type=$response_type&scope=$this->scope&nonce=$nonce&redirect_uri=$redirect");
        die();
    }

    public function get_token($code): void
    {
        $redirect = urlencode("$this->phpmyadminUrl/auth.php?callback=1");
        $grant_type = 'authorization_code';

        $params = "grant_type=$grant_type&client_id=$this->client_id&client_secret=$this->client_secret&code=$code&scope=$this->scope&redirect_uri=$redirect";

        $response = $this->curl("$this->baseUrl/token", $params);

        if (!$response || isset($response['error']) || empty($response['access_token'])) {
            $this->clear_session_cookies();
            header("Location: $this->phpmyadminUrl/auth.php$this->query");
            die();
        }

        // The token arrives straight from Keycloak's token endpoint over TLS, but we still
        // run it through introspection so the role gate reads from a Keycloak-verified
        // claim set, never from a token we decoded ourselves.
        $claims = $this->introspect($response['access_token']);

        if ($claims === null || !$this->claims_have_role($claims, 'PHPMyAdmin')) {
            $this->clear_session_cookies();
            header("Location: $this->phpmyadminUrl/auth.php$this->query");
            die();
        }

        $this->store_session_cookies($response['access_token'], $response['refresh_token'] ?? '', $claims);

        header("Location: $this->phpmyadminUrl/index.php$this->query");
        die();
    }

    public function check_token(): ?array
    {
        if (!isset($_COOKIE['access_token'])) {
            header("Location: $this->phpmyadminUrl/auth.php$this->query");
            die();
        }

        $claims = $this->introspect($_COOKIE['access_token']);

        if ($claims !== null) {
            return $claims;
        }

        // The access token is expired, revoked, or forged. Try a refresh if we have one;
        // otherwise bounce back to the auth flow.
        if (isset($_COOKIE['refresh_token'])) {
            $this->refresh_token(); // refreshes, re-validates, and redirects; never returns
        }

        $this->clear_session_cookies();
        header("Location: $this->phpmyadminUrl/auth.php$this->query");
        die();
    }

    #[NoReturn] public function refresh_token(): void
    {
        $grant_type = 'refresh_token';
        $refresh_token = $_COOKIE['refresh_token'] ?? '';

        $params = "grant_type=$grant_type&client_id=$this->client_id&client_secret=$this->client_secret&scope=$this->scope&refresh_token=$refresh_token";

        $response = $this->curl("$this->baseUrl/token", $params);

        if (!$response || isset($response['error']) || empty($response['access_token']) || empty($response['refresh_token'])) {
            $this->clear_session_cookies();
            header("Location: $this->phpmyadminUrl/auth.php$this->query");
            die();
        }

        $claims = $this->introspect($response['access_token']);

        if ($claims === null || !$this->claims_have_role($claims, 'PHPMyAdmin')) {
            $this->clear_session_cookies();
            header("Location: $this->phpmyadminUrl/auth.php$this->query");
            die();
        }

        $this->store_session_cookies($response['access_token'], $response['refresh_token'], $claims);

        header("Location: $this->phpmyadminUrl/index.php$this->query");
        die();
    }

    public function has_role($realmRole): bool
    {
        $claims = $this->check_token();

        return $claims !== null && $this->claims_have_role($claims, $realmRole);
    }

    // --- internals -----------------------------------------------------------

    /**
     * Validate a token at Keycloak's introspection endpoint and return the
     * Keycloak-verified claim set when the token is active, otherwise null.
     * This is the security boundary: signature, expiry and revocation are
     * checked by Keycloak, and the roles we trust come from this response,
     * not from a cookie the browser sent us.
     */
    private function introspect(string $token): ?array
    {
        if ($token === '') {
            return null;
        }

        $params = 'client_id=' . urlencode($this->client_id)
            . '&client_secret=' . urlencode($this->client_secret)
            . '&token=' . urlencode($token);

        $response = $this->curl("$this->baseUrl/token/introspect", $params);

        if (!is_array($response) || empty($response['active'])) {
            return null;
        }

        return $response;
    }

    private function claims_have_role(array $claims, string $role): bool
    {
        $clientRoles = $claims['resource_access'][$this->client_id]['roles'] ?? [];
        $realmRoles = $claims['realm_access']['roles'] ?? [];

        return in_array($role, $clientRoles, true) || in_array($role, $realmRoles, true);
    }

    private function store_session_cookies(string $accessToken, string $refreshToken, array $claims): void
    {
        $accessExpiry = isset($claims['exp']) ? (int)$claims['exp'] : time() + 3600;

        $this->set_secure_cookie('access_token', $accessToken, $accessExpiry);

        if ($refreshToken !== '') {
            $this->set_secure_cookie('refresh_token', $refreshToken, time() + (60 * 60 * 10));
        }
    }

    private function clear_session_cookies(): void
    {
        foreach (['access_token', 'refresh_token'] as $name) {
            if (isset($_COOKIE[$name])) {
                unset($_COOKIE[$name]);
                $this->set_secure_cookie($name, '', time() - 3600);
            }
        }
    }

    private function set_secure_cookie(string $name, string $value, int $expires): void
    {
        setcookie($name, $value, [
            'expires' => $expires,
            'path' => '/',
            'secure' => true,
            'httponly' => true,
            'samesite' => 'Lax',
        ]);
    }

    public function filtered_querystring(): string
    {
        $result = [];

        if (isset($_SERVER["QUERY_STRING"]) && $_SERVER["QUERY_STRING"] != '') {
            $query = explode('&', $_SERVER["QUERY_STRING"]);

            foreach ($query as $value) {
                $key = explode('=', $value)[0];

                if ($value != '' && $key != 'callback' && $key != 'code' && $key != 'state' && $key != 'session_state') {
                    $result[$key] = $key . '=' . (explode('=', $value)[1] ?? '');
                }
            }

            return '?' . implode('&', $result);
        }

        return '';
    }

    private function curl($url, $params, $access_token = null, int $attempt = 1)
    {
        $curl = curl_init();

        $headers = [
            'Accept: application/json',
            'Content-Type: application/x-www-form-urlencoded',
        ];

        if ($access_token !== null) {
            $headers[] = 'Authorization: Bearer ' . $access_token;
        }

        curl_setopt_array($curl, array(
            CURLOPT_URL => $url,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_ENCODING => '',
            CURLOPT_MAXREDIRS => 10,
            CURLOPT_TIMEOUT => 15,
            CURLOPT_CONNECTTIMEOUT => 10,
            CURLOPT_FOLLOWLOCATION => true,
            CURLOPT_HTTP_VERSION => CURL_HTTP_VERSION_1_1,
            CURLOPT_CUSTOMREQUEST => 'POST',
            CURLOPT_POSTFIELDS => $params,
            CURLOPT_HTTPHEADER => $headers,
        ));

        $response = curl_exec($curl);
        curl_close($curl);

        // Bounded retry on transient transport failure. The previous version recursed
        // unconditionally whenever the body was empty, which hung the request forever
        // if Keycloak was unreachable or returned an empty error body.
        if (($response === false || $response === '') && $attempt < 3) {
            return $this->curl($url, $params, $access_token, $attempt + 1);
        }

        if ($response === false || $response === '') {
            return null;
        }

        return json_decode($response, true);
    }
}
