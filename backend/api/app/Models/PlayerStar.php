<?php

namespace App\Models;

use MongoDB\Laravel\Eloquent\Model;

class PlayerStar extends Model
{
    protected $connection = 'mongodb';
    protected $collection = 'player_stars';

    protected $fillable = [
        'player_id',
        'tier',
        'achieved_bronze_at',
        'achieved_silver_at',
        'achieved_gold_at',
        'achieved_platinum_at',
        'achieved_diamond_at',
    ];

    protected $casts = [
        'achieved_bronze_at' => 'datetime',
        'achieved_silver_at' => 'datetime',
        'achieved_gold_at' => 'datetime',
        'achieved_platinum_at' => 'datetime',
        'achieved_diamond_at' => 'datetime',
    ];

    /**
     * Get the player
     */
    public function player()
    {
        return $this->belongsTo(User::class, 'player_id', '_id');
    }

    /**
     * Check if tier has been achieved
     */
    public function hasTier(string $tier): bool
    {
        $field = 'achieved_' . strtolower($tier) . '_at';
        return !is_null($this->$field);
    }

    /**
     * Get all achieved tiers
     */
    public function getAchievedTiers(): array
    {
        $tiers = [];

        if ($this->achieved_bronze_at) $tiers[] = 'Bronze';
        if ($this->achieved_silver_at) $tiers[] = 'Silver';
        if ($this->achieved_gold_at) $tiers[] = 'Gold';
        if ($this->achieved_platinum_at) $tiers[] = 'Platinum';
        if ($this->achieved_diamond_at) $tiers[] = 'Diamond';

        return $tiers;
    }
}
