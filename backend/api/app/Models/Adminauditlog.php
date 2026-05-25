<?php

namespace App\Models;

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

class AdminAuditLog
{
    // ── Action constants ───────────────────────────────────────────────────────
    const ACTION_ADD_QUESTION      = 'add_question';
    const ACTION_UPDATE_QUESTION   = 'update_question';
    const ACTION_DELETE_QUESTION   = 'delete_question';
    const ACTION_RESTORE_QUESTION  = 'restore_question';

    const ACTION_UPDATE_DIFFICULTY = 'update_difficulty';

    const ACTION_ADD_PLAYER        = 'add_player';
    const ACTION_UPDATE_PLAYER     = 'update_player';
    const ACTION_DELETE_PLAYER     = 'delete_player';
    const ACTION_CHANGE_PLAYER_PW  = 'change_player_password';

    const ACTION_AWARD_BADGE       = 'award_badge';

    const ACTION_ADD_ADMIN         = 'add_admin';
    const ACTION_UPDATE_ADMIN      = 'update_admin';
    const ACTION_DELETE_ADMIN      = 'delete_admin';
    const ACTION_CHANGE_ADMIN_PW   = 'change_admin_password';

    // Human-readable labels shown in the UI
    const LABELS = [
        'add_question'           => 'Added Question',
        'update_question'        => 'Updated Question',
        'delete_question'        => 'Deleted Question',
        'restore_question'       => 'Restored Question',
        'update_difficulty'      => 'Updated Difficulty Settings',
        'add_player'             => 'Added Player',
        'update_player'          => 'Updated Player',
        'delete_player'          => 'Deleted Player',
        'change_player_password' => 'Changed Player Password',
        'award_badge'            => 'Awarded Badge',
        'add_admin'              => 'Added Admin',
        'update_admin'           => 'Updated Admin',
        'delete_admin'           => 'Deleted Admin',
        'change_admin_password'  => 'Changed Admin Password',
    ];

    // ── Core helpers ───────────────────────────────────────────────────────────

    /**
     * Convert any value so it is safe to store in MongoDB.
     *
     * The critical problem this solves:
     *   PHP []  -->  BSON array  -->  Compass shows "Array (empty)"  ❌
     *   PHP (object)[]  -->  BSON document  -->  Compass shows "Object"  ✅
     *
     * Rules:
     *   - An empty PHP array          → cast to (object)[] (empty document)
     *   - A sequential PHP array      → leave as array (BSON array is fine here)
     *   - An associative PHP array    → cast to (object)$array (BSON document)
     *   - Nested arrays/objects       → recurse
     *   - Everything else (scalars)   → pass through unchanged
     */
    private static function bsonSafe(mixed $value): mixed
    {
        if (!is_array($value)) {
            return $value;
        }

        // Empty array → always store as document
        if (empty($value)) {
            return (object) [];
        }

        // Check if associative (has at least one string key)
        $isAssoc = array_keys($value) !== range(0, count($value) - 1);

        if ($isAssoc) {
            // Associative → BSON document: recurse into values
            $out = [];
            foreach ($value as $k => $v) {
                $out[$k] = self::bsonSafe($v);
            }
            return (object) $out;
        }

        // Sequential array → BSON array: recurse into items
        return array_map([self::class, 'bsonSafe'], $value);
    }

    // ── diff() ─────────────────────────────────────────────────────────────────

    /**
     * Return only the keys that changed between $before and $after as
     * ['before' => {...}, 'after' => {...}].
     *
     * Both sides are always returned as BSON documents (never BSON arrays),
     * even when they have no changed keys.
     */
    public static function diff(array $before, array $after): object
    {
        $changedBefore = [];
        $changedAfter  = [];

        $allKeys = array_unique(array_merge(array_keys($before), array_keys($after)));

        foreach ($allKeys as $key) {
            // Skip internal / unhelpful keys
            if (in_array($key, ['password', 'updated_at', 'created_at', '_id'], true)) {
                continue;
            }

            $bVal = $before[$key] ?? null;
            $aVal = $after[$key]  ?? null;

            // Loose comparison so "1" == 1 doesn't trigger a false change
            if ($bVal != $aVal) {
                $changedBefore[$key] = $bVal;
                $changedAfter[$key]  = $aVal;
            }
        }

        return (object) [
            'before' => self::bsonSafe($changedBefore),
            'after'  => self::bsonSafe($changedAfter),
        ];
    }

    // ── record() ───────────────────────────────────────────────────────────────

    /**
     * Write one audit-log document to MongoDB.
     *
     * @param  mixed       $admin          Authenticated admin object (from DB::table)
     * @param  string      $action         One of the ACTION_* constants
     * @param  string      $targetType     'question' | 'player' | 'admin' | 'difficulty'
     * @param  string|null $targetId       Stringified document / row ID
     * @param  string|null $targetUsername Username of the affected user (if any)
     * @param  array|object $changes       ['before' => [...], 'after' => [...]]
     *                                     — OR — the object returned by diff()
     * @param  array       $details        Any extra context to store
     */
    public static function record(
        mixed        $admin,
        string       $action,
        string       $targetType,
        string|null  $targetId,
        string|null  $targetUsername,
        array|object $changes = [],
        array        $details = [],
    ): void {
        try {
            // ── Normalise $changes ────────────────────────────────────────────
            // Accepts either:
            //   (a) an object already returned by diff()
            //   (b) an associative array like ['before' => [...], 'after' => [...]]
            //   (c) a plain empty array []
            if (is_object($changes)) {
                // Already a stdClass from diff() — just make sure nested values
                // are BSON-safe too.
                $safeChanges = (object) [
                    'before' => self::bsonSafe((array)($changes->before ?? [])),
                    'after'  => self::bsonSafe((array)($changes->after  ?? [])),
                ];
            } elseif (is_array($changes) && isset($changes['before'], $changes['after'])) {
                $safeChanges = (object) [
                    'before' => self::bsonSafe($changes['before']),
                    'after'  => self::bsonSafe($changes['after']),
                ];
            } else {
                // Unexpected shape — store as empty object so Compass shows Object
                $safeChanges = (object) [
                    'before' => (object) [],
                    'after'  => (object) [],
                ];
            }

            // ── Normalise $details ────────────────────────────────────────────
            // Always store as a BSON document, never a BSON array.
            $safeDetails = self::bsonSafe(empty($details) ? [] : $details);

            // ── Build the document ────────────────────────────────────────────
            $doc = [
                'admin_id'        => (string) ($admin->id ?? $admin->admin_id ?? 'unknown'),
                'admin_username'  => $admin->admin_username ?? 'unknown',
                'action'          => $action,
                'action_label'    => self::LABELS[$action] ?? ucwords(str_replace('_', ' ', $action)),
                'target_type'     => $targetType,
                'target_id'       => $targetId ? (string) $targetId : null,
                'target_username' => $targetUsername,
                'changes'         => $safeChanges,
                'details'         => $safeDetails,
                'updated_at'      => now(),
                'created_at'      => now(),
            ];

            DB::connection('mongodb')->table('admin_audit_logs')->insert($doc);

        } catch (\Throwable $e) {
            // Never let audit-log failures crash the main request
            Log::error('AdminAuditLog::record failed', [
                'action'  => $action,
                'error'   => $e->getMessage(),
                'trace'   => $e->getTraceAsString(),
            ]);
        }
    }
}
