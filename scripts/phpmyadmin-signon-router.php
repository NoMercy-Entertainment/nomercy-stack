<?php
// Router for check-phpmyadmin-signon.sh: serves the real phpmyadmin/*.php files under PHP's built-in
// server. DotEnv is loaded first because KeycloakClient.php requires it from the container path.
$root = dirname(__DIR__) . '/phpmyadmin';
// A CI runner's PHP may lack the curl extension. Then every curl call fails here the way a dead
// Keycloak does, so the test still reaches the token exchange instead of a fatal error.
if (!function_exists('curl_init')) {
    foreach (['CURLOPT_URL', 'CURLOPT_RETURNTRANSFER', 'CURLOPT_ENCODING', 'CURLOPT_MAXREDIRS', 'CURLOPT_TIMEOUT',
              'CURLOPT_CONNECTTIMEOUT', 'CURLOPT_FOLLOWLOCATION', 'CURLOPT_HTTP_VERSION', 'CURL_HTTP_VERSION_1_1',
              'CURLOPT_CUSTOMREQUEST', 'CURLOPT_POSTFIELDS', 'CURLOPT_HTTPHEADER', 'CURLOPT_USERPWD'] as $i => $name) {
        define($name, 10000 + $i);
    }
    function curl_init() { return null; }
    function curl_setopt_array($handle, array $options) { return true; }
    function curl_setopt($handle, int $option, $value) { return true; }
    function curl_exec($handle) { return false; }
    function curl_close($handle) { }
}
require $root . '/classes/DotEnv.php';
$path = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
if (!in_array($path, ['/auth.php', '/logout.php'], true)) {
    http_response_code(404);
    return true;
}
require $root . $path;
return true;
