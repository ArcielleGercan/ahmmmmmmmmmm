<?php

namespace App\Http\Controllers;

use App\Models\FastestTime;
use App\Models\User;
use App\Models\PlayerStats;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Validator;
use MongoDB\BSON\ObjectId;

class FastestTimeController extends Controller
{
    // ─── Helper: get the right query builder for a game type ─────────────────

    private function queryFor(string $gameType)
    {
        return $gameType === 'memory_match'
            ? FastestTime::queryMemoryMatch()
            : FastestTime::queryPuzzle();
    }

    // ─────────────────────────────────────────────────────────────────────────

    public function saveFastestTime(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'player_id'    => 'required|string',
            'game_type'    => 'required|in:memory_match,puzzle',
            'difficulty'   => 'required|in:EASY,AVERAGE,DIFFICULT',
            'category'     => 'nullable|string',
            'time_seconds' => 'required|integer|min:1',
            'moves'        => 'required|integer|min:0',
        ]);

        if ($validator->fails()) {
            return response()->json(['success' => false, 'errors' => $validator->errors()], 422);
        }

        try {
            $data           = $validator->validated();
            $playerObjectId = new ObjectId($data['player_id']);

            $player = User::find($playerObjectId);
            if (!$player) {
                return response()->json(['success' => false, 'message' => 'Player not found'], 404);
            }

            // Query the CORRECT collection
            $q = $this->queryFor($data['game_type'])
                ->where('player_id', $playerObjectId)
                ->where('difficulty', $data['difficulty']);

            if ($data['game_type'] === 'puzzle' && isset($data['category'])) {
                $q->where('category', $data['category']);
            }

            $existing     = $q->first();
            $isNewRecord  = false;
            $isFasterTime = false;

            if ($existing) {
                if ($data['time_seconds'] < $existing->time_seconds) {
                    $existing->update([
                        'time_seconds' => $data['time_seconds'],
                        'moves'        => $data['moves'],
                        'achieved_at'  => now(),
                    ]);
                    $isNewRecord  = true;
                    $isFasterTime = true;
                }
                $record = $existing->fresh();
            } else {
                $instance = FastestTime::forGameType($data['game_type']);
                $record   = $instance->newQuery()->create([
                    'player_id'       => $playerObjectId,
                    'player_username' => $player->username,
                    'game_type'       => $data['game_type'],
                    'difficulty'      => $data['difficulty'],
                    'category'        => $data['category'] ?? null,
                    'time_seconds'    => $data['time_seconds'],
                    'moves'           => $data['moves'],
                    'achieved_at'     => now(),
                ]);
                $isNewRecord = true;
            }

            PlayerStats::updateStats(
                (string) $playerObjectId,
                $data['game_type'],
                $data['category'] ?? null,
                $data['difficulty'],
                'won',
                0
            );

            return response()->json([
                'success'        => true,
                'is_new_record'  => $isNewRecord,
                'is_faster_time' => $isFasterTime,
                'data'           => $record,
            ], 200);

        } catch (\Exception $e) {
            return response()->json(['success' => false, 'message' => 'Error saving fastest time', 'error' => $e->getMessage()], 500);
        }
    }

    /**
     * GET /api/game/fastest-time/{playerId}/{gameType}/{difficulty}
     * For puzzle, pass ?category=Solar%20System
     */
    public function getPlayerFastestTime(Request $request, $playerId, $gameType, $difficulty)
    {
        try {
            $playerObjectId = new ObjectId($playerId);
            $category       = $request->query('category');

            $q = $this->queryFor($gameType)
                ->where('player_id', $playerObjectId)
                ->where('difficulty', $difficulty);

            if ($gameType === 'puzzle') {
                if (!$category) {
                    return response()->json(['success' => false, 'message' => 'Category is required for puzzle'], 400);
                }
                $q->where('category', $category);
            }

            return response()->json(['success' => true, 'data' => $q->first()], 200);

        } catch (\Exception $e) {
            return response()->json(['success' => false, 'message' => 'Error fetching fastest time', 'error' => $e->getMessage()], 500);
        }
    }

    /**
     * GET /api/game/fastest-time/{playerId}/puzzle/{difficulty}/{category}
     *
     * Category arrives as a PATH segment (URL-encoded by the client).
     * Laravel auto-decodes route parameters, so {category} is already a plain
     * string by the time it reaches this method — no urldecode() needed.
     *
     * FIX: removed the redundant urldecode() call and added diagnostic logging
     *      so mismatches between the stored value and the incoming value are
     *      immediately visible in storage/logs/laravel.log.
     */
    public function getPlayerPuzzleFastestTimeByCategory($playerId, $difficulty, $category)
    {
        try {
            $playerObjectId = new ObjectId($playerId);

            // Laravel already URL-decodes route segments; no urldecode() needed.
            // Trim just in case of accidental whitespace.
            $cleanCategory = trim($category);

            Log::info('[Puzzle Stat] lookup', [
                'player_id'  => $playerId,
                'difficulty' => $difficulty,
                'category'   => $cleanCategory,
            ]);

            $record = FastestTime::queryPuzzle()
                ->where('player_id', $playerObjectId)
                ->where('difficulty', $difficulty)
                ->where('category', $cleanCategory)
                ->first();

            Log::info('[Puzzle Stat] result', [
                'found'        => $record !== null,
                'time_seconds' => $record?->time_seconds,
            ]);

            return response()->json(['success' => true, 'data' => $record], 200);

        } catch (\Exception $e) {
            Log::error('[Puzzle Stat] error', ['message' => $e->getMessage()]);
            return response()->json([
                'success' => false,
                'message' => 'Error fetching puzzle fastest time',
                'error'   => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * GET /api/game/fastest-times/leaderboard
     */
    public function getGlobalLeaderboard(Request $request)
    {
        try {
            $gameType   = $request->query('game_type', 'memory_match');
            $difficulty = $request->query('difficulty', 'EASY');
            $category   = $request->query('category');
            $limit      = (int) $request->query('limit', 10);

            $q = $this->queryFor($gameType)->where('difficulty', $difficulty);

            if ($gameType === 'puzzle') {
                if (!$category) {
                    return response()->json(['success' => false, 'message' => 'Category is required for puzzle leaderboard'], 400);
                }
                $q->where('category', $category);
            }

            $leaderboard = $q->orderBy('time_seconds', 'asc')->limit($limit)->get();

            return response()->json([
                'success'    => true,
                'game_type'  => $gameType,
                'difficulty' => $difficulty,
                'category'   => $category,
                'data'       => $leaderboard,
            ], 200);

        } catch (\Exception $e) {
            return response()->json(['success' => false, 'message' => 'Error fetching leaderboard', 'error' => $e->getMessage()], 500);
        }
    }

    /**
     * GET /api/game/fastest-time/{playerId}/all
     */
    public function getPlayerAllRecords($playerId)
    {
        try {
            $playerObjectId = new ObjectId($playerId);

            $memoryRecords = FastestTime::queryMemoryMatch()
                ->where('player_id', $playerObjectId)
                ->orderBy('achieved_at', 'desc')
                ->get();

            $puzzleRecords = FastestTime::queryPuzzle()
                ->where('player_id', $playerObjectId)
                ->orderBy('achieved_at', 'desc')
                ->get();

            $allRecords = $memoryRecords->merge($puzzleRecords);

            $grouped = $allRecords->groupBy('game_type')->map(function ($gameRecords) {
                return $gameRecords->groupBy('difficulty')->map(function ($diffRecords) {
                    return $diffRecords->groupBy('category');
                });
            });

            return response()->json([
                'success'     => true,
                'data'        => $grouped,
                'raw_records' => $allRecords,
            ], 200);

        } catch (\Exception $e) {
            return response()->json(['success' => false, 'message' => 'Error fetching player records', 'error' => $e->getMessage()], 500);
        }
    }

    /**
     * GET /api/game/fastest-time/{playerId}/rank
     */
    public function getPlayerRank(Request $request, $playerId)
    {
        try {
            $gameType       = $request->query('game_type', 'memory_match');
            $difficulty     = $request->query('difficulty', 'EASY');
            $category       = $request->query('category');
            $playerObjectId = new ObjectId($playerId);

            $q = $this->queryFor($gameType)->where('difficulty', $difficulty);

            if ($gameType === 'puzzle' && $category) {
                $q->where('category', $category);
            }

            $allTimes     = $q->orderBy('time_seconds', 'asc')->get();
            $rank         = null;
            $playerRecord = null;

            foreach ($allTimes as $index => $record) {
                if ((string) $record->player_id === (string) $playerObjectId) {
                    $rank         = $index + 1;
                    $playerRecord = $record;
                    break;
                }
            }

            return response()->json([
                'success'       => true,
                'rank'          => $rank,
                'total_players' => $allTimes->count(),
                'player_record' => $playerRecord,
                'game_type'     => $gameType,
                'difficulty'    => $difficulty,
                'category'      => $category,
            ], 200);

        } catch (\Exception $e) {
            return response()->json(['success' => false, 'message' => 'Error fetching player rank', 'error' => $e->getMessage()], 500);
        }
    }

    /**
     * GET /api/game/fastest-time/{playerId}/puzzle/{difficulty}/all-categories
     *
     * NOTE: In api.php this route is registered BEFORE the {category} wildcard
     *       route so Laravel matches the literal string "all-categories" here
     *       and does NOT treat it as a category value.
     */
    public function getPlayerPuzzleRecordsByDifficulty($playerId, $difficulty)
    {
        try {
            $playerObjectId = new ObjectId($playerId);

            $records = FastestTime::queryPuzzle()
                ->where('player_id', $playerObjectId)
                ->where('difficulty', $difficulty)
                ->orderBy('time_seconds', 'asc')
                ->get()
                ->keyBy('category');

            return response()->json([
                'success'    => true,
                'difficulty' => $difficulty,
                'data'       => $records,
            ], 200);

        } catch (\Exception $e) {
            return response()->json(['success' => false, 'message' => 'Error fetching puzzle records', 'error' => $e->getMessage()], 500);
        }
    }
}