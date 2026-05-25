<?php

/**
 * MongoDB Collections Seeder
 *
 * This seeder creates and populates MongoDB collections with sample data:
 * - player_info (20 sample players)
 * - player_stats (leaderboard data)
 * - battle_results (battle game history)
 * - fastest_times (memory match & puzzle records)
 * - player_badges (badge progress tracking)
 * - official_badges (earned badges)
 * - star_milestones (achievement records)
 *
 * Usage:
 * 1. Save this file as: database/seeders/MongoDBCollectionsSeeder.php
 * 2. Run: php artisan db:seed --class=MongoDBCollectionsSeeder
 *
 * Or add to DatabaseSeeder.php:
 * public function run() {
 *     $this->call(MongoDBCollectionsSeeder::class);
 * }
 * Then run: php artisan db:seed
 */

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use MongoDB\BSON\ObjectId;
use Carbon\Carbon;

class MongoDBCollectionsSeeder extends Seeder
{
    private $playerIds = [];
    private $avatars = [
        'assets/images-avatars/Adventurer.png',
        'assets/images-avatars/Explorer.png',
        'assets/images-avatars/Scientist.png',
        'assets/images-avatars/Scholar.png',
        'assets/images-avatars/Genius.png',
    ];

    public function run()
    {
        echo "🚀 Starting MongoDB Collections Seeding...\n\n";

        // Clear existing data (optional - comment out if you want to keep existing data)
        $this->clearCollections();

        // Step 1: Create player_info
        echo "📝 Creating player_info...\n";
        $this->createPlayerInfo();

        // Step 2: Create player_stats
        echo "📊 Creating player_stats...\n";
        $this->createPlayerStats();

        // Step 3: Create battle results
        echo "⚔️ Creating battle results...\n";
        $this->createBattleResults();

        // Step 4: Create fastest_time records
        echo "⏱️ Creating fastest_time records...\n";
        $this->createFastestTimes();

        // Step 5: Create player_badges
        echo "🏆 Creating player_badges...\n";
        $this->createPlayerBadges();

        // Step 6: Create official_badges
        echo "💎 Creating official_badges...\n";
        $this->createOfficialBadges();

        // Step 7: Create star_milestones
        echo "⭐ Creating star_milestones...\n";
        $this->createStarMilestones();

        echo "\n✅ Seeding completed successfully!\n";
        echo "📈 Summary:\n";
        echo "   - Players created: " . count($this->playerIds) . "\n";
        echo "   - Collections populated: 7\n";
    }

    private function clearCollections()
    {
        echo "🗑️ Clearing existing collections...\n";

        $collections = [
            'player_info',
            'player_stats',
            'battle_results',
            'fastest_times',
            'player_badges',
            'official_badges',
            'star_milestones'
        ];

        foreach ($collections as $collection) {
            DB::connection('mongodb')->table($collection)->truncate();
        }

        echo "   Collections cleared.\n\n";
    }

    private function createPlayerInfo()
    {
        $usernames = [
            'MathWhiz2024', 'ScienceKid', 'BrainMaster', 'QuizChamp',
            'SmartLearner', 'PuzzlePro', 'MemoryKing', 'StarStudent',
            'QuickThinker', 'BrightMind', 'CleverKid', 'StudyHero',
            'GeniusPlayer', 'TopScorer', 'FastLearner', 'WisdomSeeker',
            'KnowledgeHunter', 'ThinkFast', 'BrainGamer', 'SmartPlayer'
        ];

        $schools = [
            'Manila Science High School',
            'Quezon City Science High School',
            'Philippine Science High School',
            'Ateneo de Manila University',
            'De La Salle University'
        ];

        foreach ($usernames as $index => $username) {
            $playerId = new ObjectId();
            $this->playerIds[] = $playerId;

            // Random stars between 0-1200
            $stars = rand(0, 1200);

            DB::connection('mongodb')->table('player_info')->insert([
                '_id' => $playerId,
                'username' => $username,
                'password' => Hash::make('password123'),
                'school' => $schools[array_rand($schools)],
                'age' => rand(10, 16),
                'category' => ['Math', 'Science'][rand(0, 1)],
                'sex' => ['Male', 'Female'][rand(0, 1)],
                'region' => rand(1, 17),
                'province' => rand(1, 81),
                'city' => rand(1, 145),
                'avatar' => $this->avatars[array_rand($this->avatars)],
                'stars' => $stars,
                'created_at' => Carbon::now()->subDays(rand(1, 90)),
                'updated_at' => Carbon::now(),
            ]);
        }

        echo "   ✓ Created " . count($usernames) . " players\n";
    }

    private function createPlayerStats()
    {
        $categories = ['math', 'science'];
        $difficulties = ['easy', 'average', 'difficult'];

        foreach ($this->playerIds as $playerId) {
            $player = DB::connection('mongodb')
                ->table('player_info')
                ->where('_id', $playerId)
                ->first();

            // Generate random stats
            $challengeStats = [];
            $battleStats = [];
            $memoryStats = [];
            $puzzleStats = [];

            foreach ($categories as $category) {
                $challengeStats[$category] = [
                    'easy' => rand(0, 50),
                    'average' => rand(0, 30),
                    'difficult' => rand(0, 15),
                ];

                $battleStats[$category] = [
                    'easy' => rand(0, 40),
                    'average' => rand(0, 25),
                    'difficult' => rand(0, 10),
                ];
            }

            // Memory match stats (no category)
            $memoryStats['general'] = [
                'easy' => rand(0, 60),
                'average' => rand(0, 40),
                'difficult' => rand(0, 20),
            ];

            // Puzzle stats (by category)
            $puzzleCategories = ['solar system', 'scientists', 'inventors'];
            foreach ($puzzleCategories as $puzzleCat) {
                $puzzleStats[$puzzleCat] = [
                    'easy' => rand(0, 45),
                    'average' => rand(0, 30),
                    'difficult' => rand(0, 15),
                ];
            }

            $totalGames = array_sum(array_map(function($cat) {
                return array_sum($cat);
            }, $challengeStats)) + array_sum(array_map(function($cat) {
                return array_sum($cat);
            }, $battleStats));

            DB::connection('mongodb')->table('player_stats')->insert([
                'player_id' => $playerId,
                'username' => $player->username,
                'avatar' => $player->avatar,
                'total_games_played' => $totalGames,
                'total_wins' => (int)($totalGames * 0.6),
                'total_losses' => (int)($totalGames * 0.4),
                'challenge_stats' => $challengeStats,
                'battle_stats' => $battleStats,
                'memory_match_stats' => $memoryStats,
                'puzzle_stats' => $puzzleStats,
                'updated_at' => Carbon::now(),
                'created_at' => Carbon::now()->subDays(rand(1, 90)),
            ]);
        }

        echo "   ✓ Created stats for " . count($this->playerIds) . " players\n";
    }

    private function createBattleResults()
    {
        $categories = ['Math', 'Science'];
        $difficulties = ['Easy', 'Average', 'Difficult'];
        $battleId = new ObjectId();

        $count = 0;
        foreach ($this->playerIds as $playerId) {
            // Create 3-8 battle results per player
            $numBattles = rand(3, 8);

            for ($i = 0; $i < $numBattles; $i++) {
                $category = $categories[array_rand($categories)];
                $difficulty = $difficulties[array_rand($difficulties)];
                $questionsAnswered = 10;
                $correctAnswers = rand(3, 10);
                $result = $correctAnswers >= 6 ? 'won' : 'lost';
                $score = $correctAnswers * 10;

                DB::connection('mongodb')->table('battle_results')->insert([
                    'player_id' => $playerId,
                    'category' => $category,
                    'difficulty_level' => $difficulty,
                    'score' => $score,
                    'result' => $result,
                    'battle_id' => (string)$battleId,
                    'questions_answered' => $questionsAnswered,
                    'correct_answers' => $correctAnswers,
                    'created_at' => Carbon::now()->subDays(rand(1, 60)),
                    'updated_at' => Carbon::now()->subDays(rand(1, 60)),
                ]);

                $count++;
            }
        }

        echo "   ✓ Created $count battle results\n";
    }

    private function createFastestTimes()
    {
        $difficulties = ['EASY', 'AVERAGE', 'DIFFICULT'];
        $puzzleCategories = ['Solar System', 'Scientists', 'Inventors'];

        $count = 0;

        foreach ($this->playerIds as $playerId) {
            $player = DB::connection('mongodb')
                ->table('player_info')
                ->where('_id', $playerId)
                ->first();

            // Memory Match records (2-5 per player)
            $numMemory = rand(2, 5);
            for ($i = 0; $i < $numMemory; $i++) {
                $difficulty = $difficulties[array_rand($difficulties)];
                $baseTime = ['EASY' => 60, 'AVERAGE' => 120, 'DIFFICULT' => 180];
                $timeSeconds = $baseTime[$difficulty] + rand(-30, 30);
                $moves = rand(10, 50);

                DB::connection('mongodb')->table('fastest_times')->insert([
                    'player_id' => $playerId,
                    'player_username' => $player->username,
                    'game_type' => 'memory_match',
                    'difficulty' => $difficulty,
                    'category' => null,
                    'time_seconds' => $timeSeconds,
                    'moves' => $moves,
                    'achieved_at' => Carbon::now()->subDays(rand(1, 60)),
                    'created_at' => Carbon::now()->subDays(rand(1, 60)),
                    'updated_at' => Carbon::now()->subDays(rand(1, 60)),
                ]);

                $count++;
            }

            // Puzzle records (3-7 per player)
            $numPuzzle = rand(3, 7);
            for ($i = 0; $i < $numPuzzle; $i++) {
                $difficulty = $difficulties[array_rand($difficulties)];
                $category = $puzzleCategories[array_rand($puzzleCategories)];
                $baseTime = ['EASY' => 90, 'AVERAGE' => 150, 'DIFFICULT' => 240];
                $timeSeconds = $baseTime[$difficulty] + rand(-40, 40);
                $moves = rand(15, 60);

                DB::connection('mongodb')->table('fastest_times')->insert([
                    'player_id' => $playerId,
                    'player_username' => $player->username,
                    'game_type' => 'puzzle',
                    'difficulty' => $difficulty,
                    'category' => $category,
                    'time_seconds' => $timeSeconds,
                    'moves' => $moves,
                    'achieved_at' => Carbon::now()->subDays(rand(1, 60)),
                    'created_at' => Carbon::now()->subDays(rand(1, 60)),
                    'updated_at' => Carbon::now()->subDays(rand(1, 60)),
                ]);

                $count++;
            }
        }

        echo "   ✓ Created $count fastest time records\n";
    }

    private function createPlayerBadges()
    {
        $count = 0;

        foreach ($this->playerIds as $playerId) {
            $easyScores = rand(0, 12);
            $avgScores = rand(0, 9);
            $diffScores = rand(0, 6);

            DB::connection('mongodb')->table('player_badges')->insert([
                '_id' => new ObjectId(),
                'player_info_id' => $playerId,
                'easy_perfect_scores' => $easyScores,
                'average_perfect_scores' => $avgScores,
                'difficult_perfect_scores' => $diffScores,
                'easy_badges_claimed' => (int)floor($easyScores / 3),
                'average_badges_claimed' => (int)floor($avgScores / 3),
                'difficult_badges_claimed' => (int)floor($diffScores / 3),
                'created_at' => Carbon::now()->subDays(rand(1, 90)),
                'updated_at' => Carbon::now(),
            ]);

            $count++;
        }

        echo "   ✓ Created $count player badge records\n";
    }

    private function createOfficialBadges()
    {
        $difficulties = ['easy', 'average', 'difficult'];
        $count = 0;

        // Get all player badges from the database
        $playerBadges = DB::connection('mongodb')
            ->table('player_badges')
            ->get();

        foreach ($playerBadges as $playerBadge) {
            // Cast object to array to access _id
            $badgeArray = (array) $playerBadge;
            $playerBadgeId = $badgeArray['_id'];

            foreach ($difficulties as $difficulty) {
                $claimedField = $difficulty . '_badges_claimed';
                $numBadges = $badgeArray[$claimedField] ?? 0;

                // Create official badges for each claimed badge
                for ($i = 1; $i <= $numBadges; $i++) {
                    $earnedDate = Carbon::now()->subDays(rand(1, 80));
                    $claimed = rand(0, 100) > 20; // 80% claimed

                    DB::connection('mongodb')->table('official_badges')->insert([
                        '_id' => new ObjectId(),
                        'player_badge_id' => $playerBadgeId,
                        'difficulty' => $difficulty,
                        'earned_date' => $earnedDate,
                        'badge_number' => $i,
                        'claimed' => $claimed,
                        'claimed_at' => $claimed ? Carbon::now()->subDays(rand(1, 70)) : null,
                        'created_at' => $earnedDate,
                        'updated_at' => Carbon::now(),
                    ]);

                    $count++;
                }
            }
        }

        echo "   ✓ Created $count official badges\n";
    }

    private function createStarMilestones()
    {
        $tiers = [
            ['tier' => 'Bronze', 'threshold' => 50, 'icon' => '🥉'],
            ['tier' => 'Silver', 'threshold' => 100, 'icon' => '🥈'],
            ['tier' => 'Gold', 'threshold' => 250, 'icon' => '🥇'],
            ['tier' => 'Platinum', 'threshold' => 500, 'icon' => '🏆'],
            ['tier' => 'Diamond', 'threshold' => 1000, 'icon' => '💎'],
        ];

        $count = 0;

        foreach ($this->playerIds as $playerId) {
            $player = DB::connection('mongodb')
                ->table('player_info')
                ->where('_id', $playerId)
                ->first();

            $playerStars = $player->stars ?? 0;

            // Create milestone records for each tier the player has passed
            foreach ($tiers as $tier) {
                if ($playerStars >= $tier['threshold']) {
                    DB::connection('mongodb')->table('star_milestones')->insert([
                        '_id' => new ObjectId(),
                        'player_id' => $playerId,
                        'tier' => $tier['tier'],
                        'icon' => $tier['icon'],
                        'prize' => $tier['tier'] . ' Badge Unlocked!',
                        'stars_at_achievement' => $tier['threshold'] + rand(0, 50),
                        'achieved_at' => Carbon::now()->subDays(rand(1, 70)),
                        'created_at' => Carbon::now()->subDays(rand(1, 70)),
                        'updated_at' => Carbon::now()->subDays(rand(1, 70)),
                    ]);

                    $count++;
                }
            }
        }

        echo "   ✓ Created $count star milestone records\n";
    }
}
