<?php

namespace App\Models;

use MongoDB\Laravel\Eloquent\Model;

class PlayerBadge extends Model
{
    protected $connection = 'mongodb';
    protected $collection = 'player_badges';

    protected $fillable = [
        'player_info_id',
        'easy_badge_count',
        'average_badge_count',
        'difficult_badge_count',
        'easy_official_badge',
        'average_official_badge',
        'difficult_official_badge',
    ];

    protected $casts = [
        'easy_badge_count' => 'integer',
        'average_badge_count' => 'integer',
        'difficult_badge_count' => 'integer',
        'easy_official_badge' => 'integer',
        'average_official_badge' => 'integer',
        'difficult_official_badge' => 'integer',
    ];

    public function player()
    {
        return $this->belongsTo(User::class, 'player_info_id', '_id');
    }

    public function rewards()
    {
        return $this->hasOne(PlayerReward::class, 'player_id', 'player_info_id');
    }

    /**
     * Get progress towards next badge
     */
    public function getProgressToNextBadge(string $difficulty): array
    {
        $badgeCountField = strtolower($difficulty) . '_badge_count';
        $badgeCount = $this->$badgeCountField ?? 0;

        $currentInSet = $badgeCount % 3;

        return [
            'current_count' => $currentInSet,
            'needed' => 3,
            'remaining' => 3 - $currentInSet,
            'percentage' => round(($currentInSet / 3) * 100, 2),
        ];
    }

    /**
     * Check if ready to earn next official badge
     */
    public function canEarnBadge(string $difficulty): bool
    {
        $badgeCountField = strtolower($difficulty) . '_badge_count';
        $badgeCount = $this->$badgeCountField ?? 0;

        return ($badgeCount > 0 && $badgeCount % 3 === 0);
    }

    /**
     * Get total official badges earned
     */
    public function getTotalOfficialBadges(): int
    {
        return ($this->easy_official_badge ?? 0) +
               ($this->average_official_badge ?? 0) +
               ($this->difficult_official_badge ?? 0);
    }
}
