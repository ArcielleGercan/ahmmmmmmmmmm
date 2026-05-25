<?php

namespace App\Models;

use MongoDB\Laravel\Eloquent\Model;

class Battle extends Model
{
    protected $connection = 'mongodb';
    protected $collection = 'battle';

    protected $fillable = [
        'player_id',
        'battle_id',
        'opponent_id',
        'opponent_username',
        'opponent_score',
        'category',
        'difficulty_level',
        'player_score',
        'result',
        'questions_answered',
        'correct_answers',
    ];

    protected $casts = [
        'opponent_score' => 'integer',
        'player_score' => 'integer',
        'questions_answered' => 'integer',
        'correct_answers' => 'integer',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];

    /**
     * Get the player who played this battle
     */
    public function player()
    {
        return $this->belongsTo(User::class, 'player_id', '_id');
    }

    /**
     * Get the opponent player
     */
    public function opponent()
    {
        return $this->belongsTo(User::class, 'opponent_id', '_id');
    }

    /**
     * Scope: Get battles by result
     */
    public function scopeByResult($query, $result)
    {
        return $query->where('result', $result);
    }

    /**
     * Scope: Get won battles
     */
    public function scopeWon($query)
    {
        return $query->where('result', 'won');
    }

    /**
     * Scope: Get lost battles
     */
    public function scopeLost($query)
    {
        return $query->where('result', 'lost');
    }
}
