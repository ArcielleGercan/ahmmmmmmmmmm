<?php

namespace App\Models;

use MongoDB\Laravel\Eloquent\Model;

class Province extends Model
{
    protected $connection = 'mongodb';
    protected $collection = 'province';
    protected $fillable = ['id', 'province_name', 'region_id'];

    protected $primaryKey = 'id';
    public $incrementing = false;
    protected $keyType = 'int';
}

