<?php
// Router for check-phpmyadmin-signon.sh: serves the real phpmyadmin/*.php files under PHP's built-in
// server. DotEnv is loaded first because KeycloakClient.php requires it from the container path.
$root = dirname(__DIR__) . '/phpmyadmin';
require $root . '/classes/DotEnv.php';
$path = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
if (!in_array($path, ['/auth.php', '/logout.php'], true)) {
    http_response_code(404);
    return true;
}
require $root . $path;
return true;
