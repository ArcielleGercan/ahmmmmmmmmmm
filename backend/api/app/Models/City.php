<?php

namespace App\Models;

use MongoDB\Laravel\Eloquent\Model;

class City extends Model
{
    protected $connection = 'mongodb';
    protected $collection = 'city';
    protected $fillable = ['id', 'city_name', 'province_id'];

    protected $primaryKey = 'id';
    public $incrementing = false;
    protected $keyType = 'int';
}

