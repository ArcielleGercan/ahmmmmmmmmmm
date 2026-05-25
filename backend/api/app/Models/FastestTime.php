<?php

namespace App\Models;

use MongoDB\Laravel\Eloquent\Model;

class FastestTime extends Model
{
    protected $connection = 'mongodb';

    protected $fillable = [
        'player_id',
        'player_username',
        'game_type',
        'difficulty',
        'category',
        'time_seconds',
        'moves',
        'achieved_at',
    ];

    protected $casts = [
        'time_seconds' => 'integer',
        'moves'        => 'integer',
        'achieved_at'  => 'datetime',
    ];

    /**
     * Dynamic collection based on game_type attribute (used on instances).
     * If $table was explicitly set (via forGameType / queryPuzzle / queryMemoryMatch),
     * respect that value first — otherwise fall back to the game_type attribute.
     */
    public function getTable(): string
    {
        // If table was explicitly set, use it
        if (isset($this->table)) {
            return $this->table;
        }
        // Otherwise derive from game_type attribute
        if (isset($this->attributes['game_type'])) {
            return $this->attributes['game_type'] === 'memory_match'
                ? 'fastest_time_memory_match'
                : 'fastest_time_puzzle';
        }
        return 'fastest_time_memory_match';
    }

    // ─── Static factory methods ───────────────────────────────────────────────
    // Use these instead of FastestTime::where(...) so the correct
    // collection is selected BEFORE the query is built.

    public static function forGameType(string $gameType): self
    {
        $instance = new self();
        $instance->table = $gameType === 'memory_match'
            ? 'fastest_time_memory_match'
            : 'fastest_time_puzzle';
        return $instance;
    }

    public static function queryMemoryMatch()
    {
        $instance = new self();
        $instance->table = 'fastest_time_memory_match';
        return $instance->newQuery();
    }

    public static function queryPuzzle()
    {
        $instance = new self();
        $instance->table = 'fastest_time_puzzle';
        return $instance->newQuery();
    }

    // ─── Scopes ───────────────────────────────────────────────────────────────

    public function scopeByGameType($query, $gameType)
    {
        return $query->where('game_type', $gameType);
    }

    public function scopeByDifficulty($query, $difficulty)
    {
        return $query->where('difficulty', $difficulty);
    }

    public function scopeByCategory($query, $category)
    {
        return $query->where('category', $category);
    }

    public function scopeTopFastest($query, $limit = 10)
    {
        return $query->orderBy('time_seconds', 'asc')->limit($limit);
    }

    public function player()
    {
        return $this->belongsTo(User::class, 'player_id', '_id');
    }
}