<?php

// Route /backend/* to Laravel
if (strpos($_SERVER['REQUEST_URI'], '/backend/') === 0) {
    $uri = substr($_SERVER['REQUEST_URI'], strlen('/backend'));
    $_SERVER['REQUEST_URI'] = $uri;
    $_SERVER['SCRIPT_NAME'] = '/index.php';
    chdir('C:/laragon/www/api/public');
    require 'C:/laragon/www/api/public/index.php';
    exit;
}

echo phpinfo();