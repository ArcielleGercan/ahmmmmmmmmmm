<?php

namespace App\Models;

use MongoDB\Laravel\Eloquent\Model;

class PlayerStats extends Model
{
    protected $connection = 'mongodb';
    protected $collection = 'player_stats';

    protected $fillable = [
        'player_id',
        'username',
        'avatar',
        'challenge_stats',
        'battle_stats',
        'memory_match_stats',
        'puzzle_stats',
    ];

    protected $casts = [
        'player_id' => 'string',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];

    /**
     * Get the player
     */
    public function player()
    {
        return $this->belongsTo(User::class, 'player_id', '_id');
    }

    /**
     * Update player stats for any game type
     */
    public static function updateStats($playerId, $gameType, $category, $difficulty, $result, $score = 0)
    {
        try {
            $playerObjectId = new \MongoDB\BSON\ObjectId($playerId);
            $categoryKey = $category ? strtolower($category) : 'general';
            $difficultyKey = strtolower($difficulty);

            // Get existing player stats record
            $playerStats = self::where('player_id', $playerObjectId)->first();

            if (!$playerStats) {
                // ✅ Only create record if there's something to count
                $shouldCreate = false;

                if (in_array($gameType, ['challenge', 'battle'])) {
                    $shouldCreate = ($result === 'won');
                } else {
                    $shouldCreate = true;
                }

                if (!$shouldCreate) {
                    \Illuminate\Support\Facades\Log::info('Skipping player_stats creation - no win to record', [
                        'player_id' => $playerId,
                        'game_type' => $gameType,
                        'result' => $result
                    ]);
                    return true;
                }

                // Get username and avatar from player_info
                $player = \Illuminate\Support\Facades\DB::connection('mongodb')
                    ->table('player_info')
                    ->where('_id', $playerObjectId)
                    ->first();

                // Initialize stats structure
                $statsData = [
                    'player_id' => $playerObjectId,
                    'username' => $player->username ?? 'Unknown',
                    'avatar' => $player->avatar ?? 'assets/images-avatars/Adventurer.png',
                    'challenge_stats' => [],
                    'battle_stats' => [],
                    'memory_match_stats' => [],
                    'puzzle_stats' => [],
                ];

                // Set initial count
                $statsField = $gameType . '_stats';
                $statsData[$statsField] = [
                    $categoryKey => [
                        $difficultyKey => 1
                    ]
                ];

                self::create($statsData);

                \Illuminate\Support\Facades\Log::info('Created new player_stats record', [
                    'player_id' => $playerId,
                    'game_type' => $gameType
                ]);
            } else {
                // ✅ FIX: Update using Eloquent model to preserve array structure
                $shouldIncrement = false;

                if (in_array($gameType, ['challenge', 'battle'])) {
                    $shouldIncrement = ($result === 'won');
                } else {
                    $shouldIncrement = true;
                }

                if ($shouldIncrement) {
                    $statsField = $gameType . '_stats';
                    $currentStats = $playerStats->$statsField ?? [];

                    // Ensure proper array structure
                    if (!is_array($currentStats)) {
                        $currentStats = [];
                    }

                    // Initialize category if needed
                    if (!isset($currentStats[$categoryKey])) {
                        $currentStats[$categoryKey] = [];
                    }

                    // Initialize difficulty if needed
                    if (!isset($currentStats[$categoryKey][$difficultyKey])) {
                        $currentStats[$categoryKey][$difficultyKey] = 0;
                    }

                    // Increment the count
                    $currentStats[$categoryKey][$difficultyKey]++;

                    // Update using Eloquent (preserves array structure)
                    $playerStats->$statsField = $currentStats;
                    $playerStats->save();

                    \Illuminate\Support\Facades\Log::info('✅ Incremented stats', [
                        'player_id' => $playerId,
                        'game_type' => $gameType,
                        'category' => $categoryKey,
                        'difficulty' => $difficultyKey,
                        'new_count' => $currentStats[$categoryKey][$difficultyKey]
                    ]);
                } else {
                    \Illuminate\Support\Facades\Log::info('Skipping stats increment - loss recorded', [
                        'player_id' => $playerId,
                        'result' => $result
                    ]);
                }
            }

            return true;
        } catch (\Exception $e) {
            \Illuminate\Support\Facades\Log::error('Error updating player stats: ' . $e->getMessage());
            \Illuminate\Support\Facades\Log::error($e->getTraceAsString());
            return false;
        }
    }

    /**
     * Get total wins for a specific mode
     */
    public function getTotalWins($mode)
    {
        $statsField = $mode . '_stats';
        $stats = $this->$statsField ?? [];

        $total = 0;
        foreach ($stats as $categoryStats) {
            if (is_array($categoryStats)) {
                foreach ($categoryStats as $count) {
                    $total += $count;
                }
            }
        }

        return $total;
    }

    /**
     * Get wins by difficulty for a mode
     */
    public function getWinsByDifficulty($mode, $difficulty)
    {
        $statsField = $mode . '_stats';
        $stats = $this->$statsField ?? [];

        $total = 0;
        foreach ($stats as $categoryStats) {
            if (is_array($categoryStats) && isset($categoryStats[$difficulty])) {
                $total += $categoryStats[$difficulty];
            }
        }

        return $total;
    }

    /**
     * Get wins by category for a mode
     */
    public function getWinsByCategory($mode, $category)
    {
        $statsField = $mode . '_stats';
        $stats = $this->$statsField ?? [];

        $categoryKey = strtolower($category);
        $categoryStats = $stats[$categoryKey] ?? [];

        $total = 0;
        if (is_array($categoryStats)) {
            foreach ($categoryStats as $count) {
                $total += $count;
            }
        }

        return $total;
    }
}
