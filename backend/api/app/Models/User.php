<?php

namespace App\Models;

use MongoDB\Laravel\Eloquent\Model;
use Illuminate\Contracts\Auth\Authenticatable;
use Illuminate\Auth\Authenticatable as AuthenticatableTrait;

class User extends Model implements Authenticatable
{
    use AuthenticatableTrait;

    protected $connection = 'mongodb';
    protected $collection = 'player_info';
    protected $table = 'player_info';

    protected $fillable = [
        'username',
        'password',
        'school',
        'age',
        'category',
        'student_category',  // ← ADD THIS LINE
        'sex',
        'region',
        'province',
        'city',
        'avatar',
        'stars',
        'game_tutorials_seen',  // ← ADD THIS LINE
    ];

    protected $hidden = [
        'password',
    ];

    protected $casts = [
        'stars' => 'integer',
        'region' => 'integer',
        'province' => 'integer',
        'city' => 'integer',
    ];

    /**
     * Get player badges
     */
    public function badges()
    {
        return $this->hasOne(PlayerBadge::class, 'player_info_id', '_id');
    }

    /**
     * Get player rewards
     */
    public function rewards()
    {
        return $this->hasOne(PlayerReward::class, 'player_id', '_id');
    }

    /**
     * Get player stars tier info
     */
    public function starTier()
    {
        return $this->hasOne(PlayerStar::class, 'player_id', '_id');
    }

    /**
     * Get player stats
     */
    public function stats()
    {
        return $this->hasOne(PlayerStats::class, 'player_id', '_id');
    }

    /**
     * Get battles
     */
    public function battles()
    {
        return $this->hasMany(Battle::class, 'player_id', '_id');
    }

    /**
     * Get fastest times
     */
    public function fastestTimes()
    {
        return $this->hasMany(FastestTime::class, 'player_id', '_id');
    }
}
