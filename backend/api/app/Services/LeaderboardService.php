// app/Services/LeaderboardService.php
<?php

namespace App\Services;

use App\Models\LeaderboardCache;
use MongoDB\BSON\ObjectId;
use Illuminate\Support\Facades\DB;

class LeaderboardService
{
    public function updateLeaderboard(?string $mode = null, ?string $category = null, ?string $difficulty = null)
    {
        try {
            $modeType = $mode === 'battle' ? 'Whiz Battle' : 'Whiz Challenge';

            $query = DB::connection('mongodb')
                ->table('game_result')
                ->where('participation_type', $modeType);

            if ($difficulty) {
                $normalizedDifficulty = ucfirst(strtolower($difficulty));
                $query->where('difficulty_level', $normalizedDifficulty);
            }

            if ($category) {
                $query->where('category', $category);
            }

            $results = $query->get()->groupBy('player_id');

            $leaderboardData = [];

            foreach ($results as $playerId => $games) {
                $playerInfo = DB::connection('mongodb')
                    ->table('player_info')
                    ->where('_id', new ObjectId($playerId))
                    ->first();

                if (!$playerInfo) continue;

                $totalRewards = $games->sum('rewards_earned');
                $easyCount = $games->where('difficulty_level', 'Easy')->count();
                $avgCount = $games->where('difficulty_level', 'Average')->count();
                $diffCount = $games->where('difficulty_level', 'Difficult')->count();

                $leaderboardData[] = [
                    'player_id' => $playerId,
                    'username' => $playerInfo->username ?? 'Unknown',
                    'avatar' => $playerInfo->avatar ?? 'assets/images-avatars/Adventurer.png',
                    'mode' => $mode ?? 'challenge',
                    'category' => $category,
                    'difficulty' => $difficulty,
                    'total_rewards' => $totalRewards,
                    'games_played' => $games->count(),
                    'easy_count' => $easyCount,
                    'average_count' => $avgCount,
                    'difficult_count' => $diffCount,
                    'last_updated' => now(),
                ];
            }

            usort($leaderboardData, function($a, $b) {
                return $b['total_rewards'] <=> $a['total_rewards'];
            });

            foreach ($leaderboardData as $index => &$data) {
                $data['rank'] = $index + 1;
            }

            LeaderboardCache::where('mode', $mode ?? 'challenge')
                ->where('category', $category)
                ->where('difficulty', $difficulty)
                ->delete();

            if (!empty($leaderboardData)) {
                LeaderboardCache::insert($leaderboardData);
            }

            \Log::info('Leaderboard cache updated', [
                'mode' => $mode,
                'category' => $category,
                'difficulty' => $difficulty,
                'players' => count($leaderboardData)
            ]);

            return count($leaderboardData);

        } catch (\Exception $e) {
            \Log::error('Error updating leaderboard cache: ' . $e->getMessage());
            return 0;
        }
    }

    public function updateAllLeaderboards()
    {
        $modes = ['challenge', 'battle'];
        $categories = ['Math', 'Science'];
        $difficulties = ['Easy', 'Average', 'Difficult'];

        $totalUpdated = 0;

        foreach ($modes as $mode) {
            $totalUpdated += $this->updateLeaderboard($mode, null, null);
        }

        foreach ($modes as $mode) {
            foreach ($categories as $category) {
                foreach ($difficulties as $difficulty) {
                    $totalUpdated += $this->updateLeaderboard($mode, $category, $difficulty);
                }
            }
        }

        \Log::info("Updated all leaderboards, total entries: {$totalUpdated}");

        return $totalUpdated;
    }
}
