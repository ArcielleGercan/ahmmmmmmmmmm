<?php

namespace App\Models;

use MongoDB\Laravel\Eloquent\Model;

class Region extends Model
{
    protected $connection = 'mongodb';
    protected $collection = 'region';
    protected $fillable = ['id', 'region_name'];

    // tell Eloquent to use "id" instead of Mongo's "_id"
    protected $primaryKey = 'id';
    public $incrementing = false;   // your "id" is Int32 from import
    protected $keyType = 'int';

    // disable _id since we’re not using it as PK
    protected $attributes = [
        '_id' => null,
    ];
}
