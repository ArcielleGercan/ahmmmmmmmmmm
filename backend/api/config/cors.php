<?php
return [
    'paths' => ['api/*', 'sanctum/csrf-cookie', 'uploads/*', 'storage/*'],

    'allowed_methods' => ['*'],

    'allowed_origins' => ['*'], // 👈 allow all origins for testing

    'allowed_origins_patterns' => [],

    'allowed_headers' => ['*'],

    'exposed_headers' => [],

    'max_age' => 0,

    'supports_credentials' => false,
];
