<?php

namespace App\Models;

use MongoDB\Laravel\Eloquent\Model;
use MongoDB\BSON\ObjectId;

class PlayerReward extends Model
{
    protected $connection = 'mongodb';
    protected $collection = 'player_rewards';

    protected $fillable = [
        'player_id',
        'difficulty',
        'badge_number',
        'earned_date',
        'requested',
        'requested_date',
        'claimed',
        'claimed_date',
        'admin_awarded',
        'awarded_date',
    ];

    protected $casts = [
        'requested'    => 'boolean',
        'claimed'      => 'boolean',
        'admin_awarded'=> 'boolean',
        'earned_date'  => 'datetime',
        'requested_date'=> 'datetime',
        'claimed_date' => 'datetime',
        'awarded_date' => 'datetime',
    ];

    // ── Scopes ────────────────────────────────────────────────────

    public function scopeByPlayer($query, $playerId)
    {
        return $query->where('player_id', new ObjectId($playerId));
    }

    public function scopeByDifficulty($query, $difficulty)
    {
        return $query->where('difficulty', $difficulty);
    }

    public function scopeUnclaimed($query)
    {
        // Rewards not yet requested by player
        return $query->where('requested', '!=', true)->where('claimed', '!=', true);
    }

    public function scopeRequested($query)
    {
        // Player has requested — pending admin confirmation
        return $query->where('requested', true)->where('claimed', '!=', true);
    }

    public function scopeClaimed($query)
    {
        // Admin has confirmed and given physical prize
        return $query->where('claimed', true);
    }

    // ── Static helpers ────────────────────────────────────────────

    /**
     * Count rewards where player tapped "Claim Reward" but admin hasn't confirmed yet.
     */
    public static function getRequestedCountByDifficulty($playerId): array
    {
        $playerObjId = new ObjectId($playerId);

        $requested = static::where('player_id', $playerObjId)
            ->where('requested', true)
            ->where('claimed', '!=', true)
            ->get();

        return [
            'easy'      => $requested->where('difficulty', 'easy')->count(),
            'average'   => $requested->where('difficulty', 'average')->count(),
            'difficult' => $requested->where('difficulty', 'difficult')->count(),
        ];
    }

    /**
     * Count rewards already confirmed by admin (claimed = true).
     */
    public static function getClaimedCountByDifficulty($playerId): array
    {
        $playerObjId = new ObjectId($playerId);

        $claimed = static::where('player_id', $playerObjId)
            ->where('claimed', true)
            ->get();

        return [
            'easy'      => $claimed->where('difficulty', 'easy')->count(),
            'average'   => $claimed->where('difficulty', 'average')->count(),
            'difficult' => $claimed->where('difficulty', 'difficult')->count(),
        ];
    }

    // ── Instance methods ──────────────────────────────────────────

    public function claim(): bool
    {
        if ($this->claimed) return false;
        $this->claimed      = true;
        $this->claimed_date = now();
        return $this->save();
    }
}
