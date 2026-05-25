<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\TestController;
use Illuminate\Support\Facades\DB;


Route::get('/post', function() {
    DB::connection('mongodb')->getClient()->selectDatabase('starbooksWhizbee')->selectCollection('pingTest')->insertOne(['hello' => 'world']);
    return 'test';
});


Route::get('/post', function () {
    DB::connection('mongodb')
        ->getClient()
        ->selectDatabase('starbooksWhizbee')
        ->selectCollection('pingTest')
        ->insertOne(['hello' => 'world']);

    return 'Mongo test inserted!';
});


