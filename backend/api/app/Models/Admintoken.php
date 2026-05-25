<?php

namespace App\Http\Controllers;

use App\Models\AdminAuditLog;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Log;
use MongoDB\BSON\ObjectId;

class AdminController extends Controller
{
    // ══════════════════════════════════════════════════════════════════════════
    //  HELPERS
    // ══════════════════════════════════════════════════════════════════════════

    /** Extract Bearer token from Authorization header or ?token= query param */
    private function extractToken(Request $request): ?string
    {
        $header = $request->header('Authorization', '');
        if (str_starts_with($header, 'Bearer ')) return substr($header, 7);
        return $request->get('token');
    }

    /**
     * Convert any form of id (MongoDB ObjectId object, ['$oid'=>...] array,
     * stdClass {$oid:...}, or plain int/string) to a plain string.
     */
    private function normaliseId($raw): string
    {
        if ($raw === null)                                  return '';
        if (is_int($raw))                                   return (string) $raw;
        if (is_string($raw))                                return $raw;
        if ($raw instanceof \MongoDB\BSON\ObjectId)         return (string) $raw;
        if (is_array($raw) && isset($raw['$oid']))          return $raw['$oid'];
        if (is_object($raw)) {
            $arr = json_decode(json_encode($raw), true);
            if (isset($arr['$oid']))                        return $arr['$oid'];
        }
        return (string) $raw;
    }

    /**
     * Validate Bearer token against admin_tokens table.
     * Returns the admin_info row (stdClass) with a normalised string ->id, or null.
     */
    private function authenticate(Request $request)
    {
        $token = $this->extractToken($request);
        if (!$token) return null;

        $tokenRow = DB::table('admin_tokens')->where('token', $token)->first();
        if (!$tokenRow) return null;

        $admin = DB::table('admin_info')->where('id', $tokenRow->admin_id)->first();
        if ($admin) {
            // Always give downstream code a plain string id to compare / log
            $admin->id = $this->normaliseId($admin->id);
        }
        return $admin;
    }

    /** Format a MongoDB question document into a clean array */
    private function formatQuestion($question): array
    {
        $q  = json_decode(json_encode($question), true);
        $id = $q['_id']['$oid'] ?? $q['id']['$oid'] ?? (string)($q['_id'] ?? $q['id'] ?? uniqid());

        return [
            'id'               => $id,
            'question'         => $q['question']         ?? '',
            'question_image'   => $q['question_image']   ?? null,
            'choice_a'         => $q['choice_a']         ?? '',
            'choice_a_image'   => $q['choice_a_image']   ?? null,
            'choice_b'         => $q['choice_b']         ?? '',
            'choice_b_image'   => $q['choice_b_image']   ?? null,
            'choice_c'         => $q['choice_c']         ?? '',
            'choice_c_image'   => $q['choice_c_image']   ?? null,
            'choice_d'         => $q['choice_d']         ?? '',
            'choice_d_image'   => $q['choice_d_image']   ?? null,
            'correct_answer'   => $q['correct_answer']   ?? '',
            'category'         => $q['category']         ?? '',
            'difficulty_level' => $q['difficulty_level'] ?? '',
            'year_level'       => $q['year_level']       ?? '',
            'subcategory'      => $q['subcategory']      ?? null,
            'has_images'       => $q['has_images']       ?? 0,
            'is_active'        => $q['is_active']        ?? 1,
            'date_added'       => $q['date_added']       ?? null,
        ];
    }

    /** Format a MongoDB player document into a clean array */
    private function formatPlayer($player): array
    {
        $p  = json_decode(json_encode($player), true);
        $id = $p['_id']['$oid'] ?? $p['id']['$oid'] ?? (string)($p['_id'] ?? $p['id'] ?? uniqid());

        return [
            'id'               => $id,
            'username'         => $p['username']         ?? '',
            'school'           => $p['school']           ?? '',
            'age'              => $p['age']              ?? '',
            'category'         => $p['category']         ?? '',
            'student_category' => $p['student_category'] ?? null,
            'sex'              => $p['sex']              ?? '',
            'avatar'           => $p['avatar']           ?? '',
            'region'           => $p['region']           ?? null,
            'province'         => $p['province']         ?? null,
            'city'             => $p['city']             ?? null,
            'stars'            => $p['stars']            ?? 0,
        ];
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  AUTH
    // ══════════════════════════════════════════════════════════════════════════

    public function login(Request $request)
    {
        $request->validate([
            'username' => 'required|string',
            'password' => 'required|string',
        ]);

        $admin = DB::table('admin_info')
            ->where('admin_username', $request->username)
            ->first();

        if (!$admin || !Hash::check($request->password, $admin->admin_password_hash)) {
            return response()->json([
                'success' => false,
                'message' => 'Invalid username or password.',
            ], 401);
        }

        $token   = bin2hex(random_bytes(32));
        $adminId = $this->normaliseId($admin->id);

        // Insert a new token row — supports multiple sessions (different devices)
        DB::table('admin_tokens')->insert([
            'admin_id'   => $adminId,
            'token'      => $token,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        // Update last_login on admin_info
        DB::table('admin_info')
            ->where('id', $adminId)
            ->update(['last_login' => now()]);

        return response()->json([
            'success' => true,
            'message' => 'Login successful.',
            'token'   => $token,
            'admin'   => [
                'id'       => $adminId,
                'username' => $admin->admin_username,
                'image'    => $admin->admin_image ?? null,
                'sex'      => $admin->admin_sex   ?? null,
            ],
        ]);
    }

    public function logout(Request $request)
    {
        $token = $this->extractToken($request);
        if ($token) {
            // Delete only this session's token — other sessions remain active
            DB::table('admin_tokens')->where('token', $token)->delete();
        }
        return response()->json(['success' => true, 'message' => 'Logged out.']);
    }

    public function profile(Request $request)
    {
        $admin = $this->authenticate($request);
        if (!$admin) return response()->json(['success' => false, 'message' => 'Unauthorized.'], 401);

        return response()->json([
            'success' => true,
            'admin'   => [
                'id'         => $admin->id, // already normalised by authenticate()
                'username'   => $admin->admin_username,
                'image'      => $admin->admin_image   ?? null,
                'sex'        => $admin->admin_sex     ?? null,
                'date_added' => $admin->date_added    ?? null,
            ],
        ]);
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  QUESTIONS
    // ══════════════════════════════════════════════════════════════════════════

    public function getQuestions(Request $request)
    {
        $admin = $this->authenticate($request);
        if (!$admin) return response()->json(['success' => false, 'message' => 'Unauthorized.'], 401);

        try {
            $query = DB::connection('mongodb')->table('quiz_questions');

            if ($request->filled('category'))   $query->where('category', ucfirst(strtolower($request->category)));
            if ($request->filled('difficulty'))  $query->where('difficulty_level', ucfirst(strtolower($request->difficulty)));
            if ($request->filled('year_level'))  $query->where('year_level', strtoupper($request->year_level));
            if ($request->filled('status'))      $query->where('is_active', (int) $request->status);

            $all = $query->get()->map(fn($q) => $this->formatQuestion($q));

            if ($request->filled('search')) {
                $search = strtolower($request->search);
                $all = $all->filter(fn($q) => str_contains(strtolower($q['question']), $search));
            }

            $sortCol = $request->get('sort_by', 'id');
            $sortDir = $request->get('sort_dir', 'asc');
            $all = $sortDir === 'desc' ? $all->sortByDesc($sortCol) : $all->sortBy($sortCol);

            $perPage = (int) $request->get('per_page', 10);
            $page    = (int) $request->get('page', 1);
            $total   = $all->count();
            $items   = $all->slice(($page - 1) * $perPage, $perPage)->values();

            return response()->json([
                'success'     => true,
                'total'       => $total,
                'page'        => $page,
                'per_page'    => $perPage,
                'total_pages' => (int) ceil($total / max($perPage, 1)),
                'questions'   => $items,
            ]);

        } catch (\Exception $e) {
            Log::error('Admin getQuestions error', ['msg' => $e->getMessage()]);
            return response()->json(['success' => false, 'message' => $e->getMessage()], 500);
        }
    }

    public function addQuestion(Request $request)
    {
        $admin = $this->authenticate($request);
        if (!$admin) return response()->json(['success' => false, 'message' => 'Unauthorized.'], 401);

        try {
            $validated = $request->validate([
                'question'         => 'required|string',
                'question_image'   => 'nullable|string',
                'choice_a'         => 'required|string',
                'choice_a_image'   => 'nullable|string',
                'choice_b'         => 'required|string',
                'choice_b_image'   => 'nullable|string',
                'choice_c'         => 'required|string',
                'choice_c_image'   => 'nullable|string',
                'choice_d'         => 'required|string',
                'choice_d_image'   => 'nullable|string',
                'correct_answer'   => 'required|string',
                'category'         => 'required|string',
                'difficulty_level' => 'required|string',
                'year_level'       => 'required|string',
                'subcategory'      => 'nullable|string',
            ]);

            $hasImages = (!empty($validated['question_image']) ||
                !empty($validated['choice_a_image']) || !empty($validated['choice_b_image']) ||
                !empty($validated['choice_c_image']) || !empty($validated['choice_d_image'])) ? 1 : 0;

            $validated['has_images'] = $hasImages;
            $validated['is_active']  = 1;
            $validated['date_added'] = now()->toISOString();

            $insertedId = DB::connection('mongodb')->table('quiz_questions')->insertGetId($validated);

            // ── AUDIT LOG ────────────────────────────────────────────────────
            AdminAuditLog::record(
                admin:          $admin,
                action:         AdminAuditLog::ACTION_ADD_QUESTION,
                targetType:     'question',
                targetId:       (string) $insertedId,
                targetUsername: null,
                changes:        ['before' => ['status' => 'did not exist'], 'after' => [
                    'question'         => $validated['question'],
                    'category'         => $validated['category'],
                    'difficulty_level' => $validated['difficulty_level'],
                    'year_level'       => $validated['year_level'],
                ]],
                details:        ['has_images' => (bool) $hasImages]
            );

            return response()->json(['success' => true, 'message' => 'Question added.', 'id' => (string) $insertedId], 201);

        } catch (\Illuminate\Validation\ValidationException $e) {
            return response()->json(['success' => false, 'message' => $e->getMessage(), 'errors' => $e->errors()], 422);
        } catch (\Exception $e) {
            return response()->json(['success' => false, 'message' => $e->getMessage()], 500);
        }
    }

    public function updateQuestion(Request $request, $id)
    {
        $admin = $this->authenticate($request);
        if (!$admin) return response()->json(['success' => false, 'message' => 'Unauthorized.'], 401);

        try {
            // Fetch before snapshot
            $existing = DB::connection('mongodb')->table('quiz_questions')->where('_id', $id)->first();
            $before   = $existing ? $this->formatQuestion($existing) : [];

            $data = $request->only([
                'question', 'question_image', 'choice_a', 'choice_a_image',
                'choice_b', 'choice_b_image', 'choice_c', 'choice_c_image',
                'choice_d', 'choice_d_image', 'correct_answer', 'category',
                'difficulty_level', 'year_level', 'subcategory', 'is_active',
            ]);
            $data['has_images'] = (!empty($data['question_image']) ||
                !empty($data['choice_a_image']) || !empty($data['choice_b_image']) ||
                !empty($data['choice_c_image']) || !empty($data['choice_d_image'])) ? 1 : 0;

            DB::connection('mongodb')->table('quiz_questions')->where('_id', $id)->update($data);

            // ── AUDIT LOG ────────────────────────────────────────────────────
            AdminAuditLog::record(
                admin:          $admin,
                action:         AdminAuditLog::ACTION_UPDATE_QUESTION,
                targetType:     'question',
                targetId:       $id,
                targetUsername: null,
                changes:        AdminAuditLog::diff($before, $data),
                details:        ['question_preview' => substr($before['question'] ?? '', 0, 80)]
            );

            return response()->json(['success' => true, 'message' => 'Question updated.']);

        } catch (\Exception $e) {
            return response()->json(['success' => false, 'message' => $e->getMessage()], 500);
        }
    }

    public function deleteQuestion(Request $request, $id)
    {
        $admin = $this->authenticate($request);
        if (!$admin) return response()->json(['success' => false, 'message' => 'Unauthorized.'], 401);

        try {
            $existing = DB::connection('mongodb')->table('quiz_questions')->where('_id', $id)->first();
            $preview  = $existing ? (json_decode(json_encode($existing), true)['question'] ?? '') : '';

            DB::connection('mongodb')->table('quiz_questions')->where('_id', $id)->update(['is_active' => 0]);

            // ── AUDIT LOG ────────────────────────────────────────────────────
            AdminAuditLog::record(
                admin:          $admin,
                action:         AdminAuditLog::ACTION_DELETE_QUESTION,
                targetType:     'question',
                targetId:       $id,
                targetUsername: null,
                changes:        ['before' => ['is_active' => 1], 'after' => ['is_active' => 0]],
                details:        ['question_preview' => substr($preview, 0, 80)]
            );

            return response()->json(['success' => true, 'message' => 'Question deactivated.']);

        } catch (\Exception $e) {
            return response()->json(['success' => false, 'message' => $e->getMessage()], 500);
        }
    }

    public function restoreQuestion(Request $request, $id)
    {
        $admin = $this->authenticate($request);
        if (!$admin) return response()->json(['success' => false, 'message' => 'Unauthorized.'], 401);

        try {
            $existing = DB::connection('mongodb')->table('quiz_questions')->where('_id', $id)->first();
            $preview  = $existing ? (json_decode(json_encode($existing), true)['question'] ?? '') : '';

            DB::connection('mongodb')->table('quiz_questions')->where('_id', $id)->update(['is_active' => 1]);

            // ── AUDIT LOG ────────────────────────────────────────────────────
            AdminAuditLog::record(
                admin:          $admin,
                action:         AdminAuditLog::ACTION_RESTORE_QUESTION,
                targetType:     'question',
                targetId:       $id,
                targetUsername: null,
                changes:        ['before' => ['is_active' => 0], 'after' => ['is_active' => 1]],
                details:        ['question_preview' => substr($preview, 0, 80)]
            );

            return response()->json(['success' => true, 'message' => 'Question restored.']);

        } catch (\Exception $e) {
            return response()->json(['success' => false, 'message' => $e->getMessage()], 500);
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  DIFFICULTY SETTINGS
    // ══════════════════════════════════════════════════════════════════════════

    public function getDifficultySettings(Request $request)
    {
        try {
            $rows   = DB::table('quiz_difficulty_settings')->get();
            $result = [];
            foreach ($rows as $row) {
                $result[$row->difficulty_level] = [
                    'id'            => $row->id,
                    'num_questions' => $row->num_questions,
                    'time_per_qn'   => $row->time_per_qn,
                    'points_per_qn' => $row->points_per_qn,
                ];
            }
            return response()->json(['success' => true, 'settings' => $result]);
        } catch (\Exception $e) {
            return response()->json(['success' => false, 'message' => $e->getMessage()], 500);
        }
    }

    public function updateDifficultySettings(Request $request, $level)
    {
        $admin = $this->authenticate($request);
        if (!$admin) return response()->json(['success' => false, 'message' => 'Unauthorized.'], 401);

        $level = ucfirst(strtolower($level));
        if (!in_array($level, ['Easy', 'Average', 'Difficult'])) {
            return response()->json(['success' => false, 'message' => 'Invalid difficulty level.'], 422);
        }

        try {
            $validated = $request->validate([
                'num_questions' => 'required|integer|min:1|max:50',
                'time_per_qn'   => 'required|integer|min:5|max:120',
                'points_per_qn' => 'required|integer|min:1|max:100',
            ]);

            // Snapshot before
            $existing = DB::table('quiz_difficulty_settings')->where('difficulty_level', $level)->first();
            $before   = $existing ? [
                'num_questions' => $existing->num_questions,
                'time_per_qn'   => $existing->time_per_qn,
                'points_per_qn' => $existing->points_per_qn,
            ] : [];

            DB::table('quiz_difficulty_settings')->where('difficulty_level', $level)->update($validated);

            // ── AUDIT LOG ────────────────────────────────────────────────────
            AdminAuditLog::record(
                admin:          $admin,
                action:         AdminAuditLog::ACTION_UPDATE_DIFFICULTY,
                targetType:     'difficulty',
                targetId:       null,
                targetUsername: null,
                changes:        AdminAuditLog::diff($before, $validated),
                details:        ['difficulty_level' => $level]
            );

            return response()->json(['success' => true, 'message' => "$level settings updated."]);

        } catch (\Illuminate\Validation\ValidationException $e) {
            return response()->json(['success' => false, 'message' => $e->getMessage(), 'errors' => $e->errors()], 422);
        } catch (\Exception $e) {
            return response()->json(['success' => false, 'message' => $e->getMessage()], 500);
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  PLAYERS
    // ══════════════════════════════════════════════════════════════════════════

    public function getPlayers(Request $request)
    {
        $admin = $this->authenticate($request);
        if (!$admin) return response()->json(['success' => false, 'message' => 'Unauthorized.'], 401);

        try {
            $query = DB::connection('mongodb')->table('player_info');

            if ($request->filled('category')) $query->where('category', $request->category);
            if ($request->filled('sex'))      $query->where('sex', $request->sex);

            $rawPlayers = $query->get();

            // Resolve location IDs → names in bulk
            $regionIds   = $rawPlayers->pluck('region')->filter()->unique()->map(fn($v) => (int)$v)->values()->toArray();
            $provinceIds = $rawPlayers->pluck('province')->filter()->unique()->map(fn($v) => (int)$v)->values()->toArray();
            $cityIds     = $rawPlayers->pluck('city')->filter()->unique()->map(fn($v) => (int)$v)->values()->toArray();

            $regionMap   = DB::table('region')->whereIn('id', $regionIds)
                ->pluck('region_name', 'id')->mapWithKeys(fn($name, $id) => [(int)$id => $name]);
            $provinceMap = DB::table('province')->whereIn('id', $provinceIds)
                ->pluck('province_name', 'id')->mapWithKeys(fn($name, $id) => [(int)$id => $name]);
            $cityMap     = DB::table('city')->whereIn('id', $cityIds)
                ->pluck('city_name', 'id')->mapWithKeys(fn($name, $id) => [(int)$id => $name]);

            $all = $rawPlayers->map(function ($p) use ($regionMap, $provinceMap, $cityMap) {
                $formatted = $this->formatPlayer($p);
                $rId = (int) ($formatted['region']   ?? 0);
                $pId = (int) ($formatted['province'] ?? 0);
                $cId = (int) ($formatted['city']     ?? 0);
                $formatted['region_name']   = $rId ? ($regionMap[$rId]   ?? null) : null;
                $formatted['province_name'] = $pId ? ($provinceMap[$pId] ?? null) : null;
                $formatted['city_name']     = $cId ? ($cityMap[$cId]     ?? null) : null;
                return $formatted;
            });

            if ($request->filled('search')) {
                $search = strtolower($request->search);
                $all = $all->filter(fn($p) =>
                    str_contains(strtolower($p['username']), $search) ||
                    str_contains(strtolower($p['school'] ?? ''), $search)
                );
            }

            $sortCol = $request->get('sort_by', 'username');
            $sortDir = $request->get('sort_dir', 'asc');
            $all = $sortDir === 'desc' ? $all->sortByDesc($sortCol) : $all->sortBy($sortCol);

            $perPage = (int) $request->get('per_page', 10);
            $page    = (int) $request->get('page', 1);
            $total   = $all->count();
            $items   = $all->slice(($page - 1) * $perPage, $perPage)->values();

            return response()->json([
                'success'     => true,
                'total'       => $total,
                'page'        => $page,
                'per_page'    => $perPage,
                'total_pages' => (int) ceil($total / max($perPage, 1)),
                'players'     => $items,
            ]);

        } catch (\Exception $e) {
            Log::error('Admin getPlayers error', ['msg' => $e->getMessage()]);
            return response()->json(['success' => false, 'message' => $e->getMessage()], 500);
        }
    }

    public function addPlayer(Request $request)
    {
        $admin = $this->authenticate($request);
        if (!$admin) return response()->json(['success' => false, 'message' => 'Unauthorized.'], 401);

        try {
            $validated = $request->validate([
                'username' => [
                    'required', 'min:3', 'max:20', 'regex:/^[a-zA-Z0-9_]+$/',
                    function ($attribute, $value, $fail) {
                        if (preg_match('/\s/', $value)) $fail('Username cannot contain spaces.');
                        $exists = DB::connection('mongodb')->table('player_info')->where('username', $value)->first();
                        if ($exists) $fail('Username is already taken.');
                    },
                ],
                'password' => [
                    'required', 'min:8',
                    'regex:/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[!@#$%^&*(),.?":{}|<>])[A-Za-z\d!@#$%^&*(),.?":{}|<>]+$/',
                ],
                'school'           => 'required|string|min:2',
                'age'              => 'required|string',
                'avatar'           => 'required|string',
                'category'         => 'required|string|in:Student,Employee,Others',
                'student_category' => 'nullable|string|in:Elementary,Junior High,Senior High,College,Postgraduate',
                'sex'              => 'required|in:Male,Female',
                'region'           => 'required|integer',
                'province'         => 'required|integer',
                'city'             => 'required|integer',
            ], [
                'username.required' => 'Username is required.',
                'username.min'      => 'Username must be at least 3 characters.',
                'username.max'      => 'Username must not exceed 20 characters.',
                'username.regex'    => 'Username can only contain letters, numbers, and underscores.',
                'password.required' => 'Password is required.',
                'password.min'      => 'Password must be at least 8 characters.',
                'password.regex'    => 'Password must contain uppercase, lowercase, number, and special character.',
                'school.required'   => 'School is required.',
                'school.min'        => 'School name must be at least 2 characters.',
                'age.required'      => 'Please select an age range.',
                'avatar.required'   => 'Avatar is required.',
                'category.required' => 'Category is required.',
                'sex.required'      => 'Sex is required.',
                'sex.in'            => 'Sex must be either Male or Female.',
                'region.required'   => 'Region is required.',
                'region.integer'    => 'Invalid region selected.',
                'province.required' => 'Province is required.',
                'province.integer'  => 'Invalid province selected.',
                'city.required'     => 'City is required.',
                'city.integer'      => 'Invalid city selected.',
            ]);

        } catch (\Illuminate\Validation\ValidationException $e) {
            $errors     = $e->errors();
            $firstError = reset($errors);
            $message    = is_array($firstError) ? $firstError[0] : $firstError;
            return response()->json(['success' => false, 'message' => $message, 'errors' => $errors], 422);
        }

        try {
            $insertedId = DB::connection('mongodb')->table('player_info')->insertGetId([
                'username'         => $validated['username'],
                'password'         => Hash::make($validated['password']),
                'school'           => $validated['school'],
                'age'              => $validated['age'],
                'avatar'           => $validated['avatar'],
                'category'         => $validated['category'],
                'student_category' => $validated['student_category'] ?? null,
                'sex'              => $validated['sex'],
                'region'           => (int) $validated['region'],
                'province'         => (int) $validated['province'],
                'city'             => (int) $validated['city'],
                'stars'            => 0,
                'created_at'       => now(),
                'updated_at'       => now(),
            ]);

            // ── AUDIT LOG ────────────────────────────────────────────────────
            AdminAuditLog::record(
                admin:          $admin,
                action:         AdminAuditLog::ACTION_ADD_PLAYER,
                targetType:     'player',
                targetId:       (string) $insertedId,
                targetUsername: $validated['username'],
                changes:        ['before' => ['status' => 'did not exist'], 'after' => [
                    'username'         => $validated['username'],
                    'school'           => $validated['school'],
                    'age'              => $validated['age'],
                    'category'         => $validated['category'],
                    'student_category' => $validated['student_category'] ?? null,
                    'sex'              => $validated['sex'],
                    'region'           => (int) $validated['region'],
                    'province'         => (int) $validated['province'],
                    'city'             => (int) $validated['city'],
                ]],
                details: ['avatar' => $validated['avatar']]
            );

            return response()->json(['success' => true, 'message' => 'Player added successfully.'], 201);

        } catch (\Exception $e) {
            Log::error('Admin addPlayer error', ['msg' => $e->getMessage()]);
            return response()->json(['success' => false, 'message' => $e->getMessage()], 500);
        }
    }

    public function updatePlayer(Request $request, $id)
    {
        $admin = $this->authenticate($request);
        if (!$admin) return response()->json(['success' => false, 'message' => 'Unauthorized.'], 401);

        try {
            $playerObjectId = new ObjectId($id);

            // Snapshot before update
            $existing = DB::connection('mongodb')->table('player_info')->where('_id', $playerObjectId)->first();
            if (!$existing) return response()->json(['success' => false, 'message' => 'Player not found.'], 404);
            $before = $this->formatPlayer($existing);

            $data = $request->only([
                'username', 'school', 'age', 'category', 'sex',
                'avatar', 'student_category', 'region', 'province', 'city',
            ]);
            $data = array_filter($data, fn($v) => $v !== null && $v !== '');

            foreach (['region', 'province', 'city'] as $field) {
                if (isset($data[$field])) $data[$field] = (int) $data[$field];
            }

            if ($request->filled('password')) {
                $data['password'] = Hash::make($request->password);
            }

            $data['updated_at'] = now();

            DB::connection('mongodb')->table('player_info')
                ->where('_id', $playerObjectId)
                ->update($data);

            // ── AUDIT LOG ────────────────────────────────────────────────────
            AdminAuditLog::record(
                admin:          $admin,
                action:         AdminAuditLog::ACTION_UPDATE_PLAYER,
                targetType:     'player',
                targetId:       $id,
                targetUsername: $before['username'] ?? null,
                changes:        AdminAuditLog::diff($before, $data),
                details:        ['player_id' => $id]
            );

            return response()->json(['success' => true, 'message' => 'Player updated.']);

        } catch (\Exception $e) {
            return response()->json(['success' => false, 'message' => $e->getMessage()], 500);
        }
    }

    public function changePlayerPassword(Request $request, $id)
    {
        $admin = $this->authenticate($request);
        if (!$admin) return response()->json(['success' => false, 'message' => 'Unauthorized.'], 401);

        try {
            $request->validate([
                'new_password' => [
                    'required', 'min:8',
                    'regex:/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[!@#$%^&*(),.?":{}|<>])[A-Za-z\d!@#$%^&*(),.?":{}|<>]+$/',
                ],
            ], [
                'new_password.required' => 'New password is required.',
                'new_password.min'      => 'Password must be at least 8 characters.',
                'new_password.regex'    => 'Password must contain uppercase, lowercase, number, and special character.',
            ]);
        } catch (\Illuminate\Validation\ValidationException $e) {
            $errors     = $e->errors();
            $firstError = reset($errors);
            $message    = is_array($firstError) ? $firstError[0] : $firstError;
            return response()->json(['success' => false, 'message' => $message], 422);
        }

        try {
            $playerObjectId = new ObjectId($id);
            $existing = DB::connection('mongodb')->table('player_info')->where('_id', $playerObjectId)->first();
            if (!$existing) return response()->json(['success' => false, 'message' => 'Player not found.'], 404);

            DB::connection('mongodb')->table('player_info')
                ->where('_id', $playerObjectId)
                ->update([
                    'password'   => Hash::make($request->new_password),
                    'updated_at' => now(),
                ]);

            // ── AUDIT LOG ────────────────────────────────────────────────────
            AdminAuditLog::record(
                admin:          $admin,
                action:         AdminAuditLog::ACTION_UPDATE_PLAYER,
                targetType:     'player',
                targetId:       $id,
                targetUsername: $existing->username ?? 'unknown',
                changes:        ['before' => ['password' => '[hidden]'], 'after' => ['password' => '[hidden — changed]']],
                details:        ['action' => 'password_reset_by_admin']
            );

            return response()->json(['success' => true, 'message' => 'Player password reset successfully.']);

        } catch (\Exception $e) {
            return response()->json(['success' => false, 'message' => $e->getMessage()], 500);
        }
    }

    public function deletePlayer(Request $request, $id)
    {
        $admin = $this->authenticate($request);
        if (!$admin) return response()->json(['success' => false, 'message' => 'Unauthorized.'], 401);

        try {
            $playerObjectId = new ObjectId($id);

            $existing = DB::connection('mongodb')->table('player_info')->where('_id', $playerObjectId)->first();
            $username = $existing ? ($existing->username ?? 'unknown') : 'unknown';

            DB::connection('mongodb')->table('player_info')->where('_id', $playerObjectId)->delete();

            // ── AUDIT LOG ────────────────────────────────────────────────────
            AdminAuditLog::record(
                admin:          $admin,
                action:         AdminAuditLog::ACTION_DELETE_PLAYER,
                targetType:     'player',
                targetId:       $id,
                targetUsername: $username,
                changes:        ['before' => ['username' => $username, 'status' => 'active'], 'after' => ['status' => 'deleted']],
                details:        ['player_id' => $id, 'deleted_by' => $admin->admin_username]
            );

            return response()->json(['success' => true, 'message' => 'Player deleted.']);

        } catch (\Exception $e) {
            return response()->json(['success' => false, 'message' => $e->getMessage()], 500);
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  AWARD BADGE
    // ══════════════════════════════════════════════════════════════════════════

    public function awardBadge(Request $request, $playerId)
    {
        $admin = $this->authenticate($request);
        if (!$admin) return response()->json(['success' => false, 'message' => 'Unauthorized.'], 401);

        $request->validate(['difficulty' => 'required|in:easy,average,difficult']);
        $difficulty = $request->difficulty;

        try {
            $playerObjectId = new ObjectId($playerId);

            // Get player for username in log
            $player   = DB::connection('mongodb')->table('player_info')->where('_id', $playerObjectId)->first();
            $username = $player ? ($player->username ?? 'unknown') : 'unknown';

            // Find all unclaimed rewards for this difficulty
            $unclaimedRewards = DB::connection('mongodb')
                ->table('player_rewards')
                ->where('player_id', $playerObjectId)
                ->where('difficulty', $difficulty)
                ->where('claimed', '!=', true)
                ->get();

            if ($unclaimedRewards->isEmpty()) {
                return response()->json([
                    'success' => false,
                    'message' => 'No pending rewards found for this difficulty.',
                ], 404);
            }

            $rewardCount = $unclaimedRewards->count();

            // Mark all as claimed + stamp which admin awarded them
            DB::connection('mongodb')
                ->table('player_rewards')
                ->where('player_id', $playerObjectId)
                ->where('difficulty', $difficulty)
                ->where('claimed', '!=', true)
                ->update([
                    'claimed'              => true,
                    'claimed_date'         => now(),
                    'admin_awarded'        => true,
                    'awarded_date'         => now(),
                    'awarded_by_admin_id'  => $admin->id,
                    'awarded_by_admin_username' => $admin->admin_username,
                    'updated_at'           => now(),
                ]);

            // Update player_badges: increment official count + reset badge_count cycle
            $officialField = $difficulty . '_official_badge';
            $countField    = $difficulty . '_badge_count';

            $playerBadge    = DB::connection('mongodb')->table('player_badges')
                ->where('player_info_id', $playerObjectId)->first();
            $currentOfficial = $playerBadge ? ($playerBadge->$officialField ?? 0) : 0;
            $newOfficial     = $currentOfficial + $rewardCount;

            DB::connection('mongodb')
                ->table('player_badges')
                ->where('player_info_id', $playerObjectId)
                ->update([
                    $officialField => $newOfficial,
                    $countField    => 0,
                    'updated_at'   => now(),
                ]);

            // ── AUDIT LOG ────────────────────────────────────────────────────
            AdminAuditLog::record(
                admin:          $admin,
                action:         AdminAuditLog::ACTION_AWARD_BADGE,
                targetType:     'player',
                targetId:       $playerId,
                targetUsername: $username,
                changes:        [
                    'before' => ['claimed' => false, $officialField => $currentOfficial],
                    'after'  => ['claimed' => true,  $officialField => $newOfficial],
                ],
                details: [
                    'difficulty'      => $difficulty,
                    'rewards_awarded' => $rewardCount,
                ]
            );

            Log::info('Admin awarded badge', [
                'admin'           => $admin->admin_username,
                'player'          => $username,
                'difficulty'      => $difficulty,
                'rewards_awarded' => $rewardCount,
                'new_official'    => $newOfficial,
            ]);

            return response()->json([
                'success' => true,
                'message' => "Reward confirmed! {$difficulty} badge awarded by {$admin->admin_username}.",
                'data'    => [
                    'difficulty'      => $difficulty,
                    'rewards_awarded' => $rewardCount,
                    'official_total'  => $newOfficial,
                    'awarded_by'      => $admin->admin_username,
                ],
            ]);

        } catch (\Exception $e) {
            Log::error('awardBadge error: ' . $e->getMessage());
            return response()->json(['success' => false, 'message' => 'Error: ' . $e->getMessage()], 500);
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  ADMINS MANAGEMENT
    // ══════════════════════════════════════════════════════════════════════════

    public function getAdmins(Request $request)
    {
        $admin = $this->authenticate($request);
        if (!$admin) return response()->json(['success' => false, 'message' => 'Unauthorized.'], 401);

        try {
            $rows = DB::table('admin_info')->get();
            $admins = $rows->map(fn($a) => [
                'id'         => $this->normaliseId($a->id),
                'username'   => $a->admin_username,
                'sex'        => $a->admin_sex    ?? null,
                'avatar'     => $a->admin_avatar ?? $a->avatar ?? null,
                'image'      => $a->admin_image  ?? null,
                'date_added' => $a->date_added   ?? null,
            ])->values();

            if ($request->filled('search')) {
                $search = strtolower($request->search);
                $admins = $admins->filter(fn($a) =>
                    str_contains(strtolower($a['username']), $search)
                )->values();
            }

            return response()->json(['success' => true, 'admins' => $admins]);

        } catch (\Exception $e) {
            return response()->json(['success' => false, 'message' => $e->getMessage()], 500);
        }
    }

    public function addAdmin(Request $request)
    {
        $admin = $this->authenticate($request);
        if (!$admin) return response()->json(['success' => false, 'message' => 'Unauthorized.'], 401);

        try {
            $request->validate([
                'username' => [
                    'required', 'min:3', 'max:20', 'regex:/^[a-zA-Z0-9_]+$/',
                    function ($attribute, $value, $fail) {
                        if (preg_match('/\s/', $value)) $fail('Username cannot contain spaces.');
                        if (DB::table('admin_info')->where('admin_username', $value)->exists()) {
                            $fail('Username is already taken.');
                        }
                    },
                ],
                'password' => [
                    'required', 'min:8',
                    'regex:/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[!@#$%^&*(),.?":{}|<>])[A-Za-z\d!@#$%^&*(),.?":{}|<>]+$/',
                ],
                'sex' => 'required|in:Male,Female',
            ], [
                'username.required' => 'Username is required.',
                'username.min'      => 'Username must be at least 3 characters.',
                'username.max'      => 'Username must not exceed 20 characters.',
                'username.regex'    => 'Username can only contain letters, numbers, and underscores.',
                'password.required' => 'Password is required.',
                'password.min'      => 'Password must be at least 8 characters.',
                'password.regex'    => 'Password must contain uppercase, lowercase, number, and special character.',
                'sex.required'      => 'Sex is required.',
                'sex.in'            => 'Sex must be either Male or Female.',
            ]);

        } catch (\Illuminate\Validation\ValidationException $e) {
            $errors     = $e->errors();
            $firstError = reset($errors);
            $message    = is_array($firstError) ? $firstError[0] : $firstError;
            return response()->json(['success' => false, 'message' => $message, 'errors' => $errors], 422);
        }

        try {
            DB::table('admin_info')->insert([
                'admin_username'      => $request->username,
                'admin_password_hash' => Hash::make($request->password),
                'admin_sex'           => $request->sex,
                'date_added'          => now()->toDateTimeString(),
            ]);

            // ── AUDIT LOG ────────────────────────────────────────────────────
            AdminAuditLog::record(
                admin:          $admin,
                action:         AdminAuditLog::ACTION_ADD_ADMIN,
                targetType:     'admin',
                targetId:       null,
                targetUsername: $request->username,
                changes:        ['before' => ['status' => 'did not exist'], 'after' => [
                    'username' => $request->username,
                    'sex'      => $request->sex,
                ]],
                details: ['created_by' => $admin->admin_username]
            );

            return response()->json(['success' => true, 'message' => 'Admin added.'], 201);

        } catch (\Exception $e) {
            return response()->json(['success' => false, 'message' => $e->getMessage()], 500);
        }
    }

    public function updateAdmin(Request $request, $id)
    {
        $admin = $this->authenticate($request);
        if (!$admin) return response()->json(['success' => false, 'message' => 'Unauthorized.'], 401);

        try {
            $target = DB::table('admin_info')->where('id', $id)->first();
            if (!$target) return response()->json(['success' => false, 'message' => 'Admin not found.'], 404);

            $before = [
                'username' => $target->admin_username,
                'sex'      => $target->admin_sex ?? null,
            ];

            $data = [];
            if ($request->filled('username')) $data['admin_username'] = $request->username;
            if ($request->filled('sex'))      $data['admin_sex']      = $request->sex;
            if ($request->filled('password')) $data['admin_password_hash'] = Hash::make($request->password);

            if (empty($data)) return response()->json(['success' => false, 'message' => 'Nothing to update.'], 422);

            DB::table('admin_info')->where('id', $id)->update($data);

            $after = [
                'username' => $request->filled('username') ? $request->username : $target->admin_username,
                'sex'      => $request->filled('sex')      ? $request->sex      : ($target->admin_sex ?? null),
            ];

            // ── AUDIT LOG ────────────────────────────────────────────────────
            AdminAuditLog::record(
                admin:          $admin,
                action:         AdminAuditLog::ACTION_UPDATE_ADMIN,
                targetType:     'admin',
                targetId:       (string) $id,
                targetUsername: $target->admin_username,
                changes:        AdminAuditLog::diff($before, $after),
                details:        ['admin_id' => (string) $id]
            );

            return response()->json(['success' => true, 'message' => 'Admin updated.']);

        } catch (\Exception $e) {
            return response()->json(['success' => false, 'message' => $e->getMessage()], 500);
        }
    }

    public function deleteAdmin(Request $request, $id)
    {
        $admin = $this->authenticate($request);
        if (!$admin) return response()->json(['success' => false, 'message' => 'Unauthorized.'], 401);

        // Prevent deleting your own account
        if ((string)$admin->id === (string)$id) {
            return response()->json(['success' => false, 'message' => 'Cannot delete your own account.'], 403);
        }

        try {
            $target = DB::table('admin_info')->where('id', $id)->first();

            if (!$target) {
                return response()->json(['success' => false, 'message' => 'Admin not found.'], 404);
            }

            $username = $target->admin_username;

            // Delete all active sessions for this admin first
            DB::table('admin_tokens')->where('admin_id', $id)->delete();

            // Delete the admin record
            $deleted = DB::table('admin_info')->where('id', $id)->delete();

            if ($deleted === 0) {
                return response()->json(['success' => false, 'message' => 'Delete failed — no rows affected.'], 500);
            }

            // ── AUDIT LOG ────────────────────────────────────────────────────
            AdminAuditLog::record(
                admin:          $admin,
                action:         AdminAuditLog::ACTION_DELETE_ADMIN,
                targetType:     'admin',
                targetId:       (string) $id,
                targetUsername: $username,
                changes:        ['before' => ['username' => $username, 'status' => 'active'], 'after' => ['status' => 'deleted']],
                details:        ['admin_id' => (string) $id, 'deleted_by' => $admin->admin_username]
            );

            return response()->json(['success' => true, 'message' => 'Admin deleted.', 'deleted_id' => (string) $id]);

        } catch (\Exception $e) {
            return response()->json(['success' => false, 'message' => $e->getMessage()], 500);
        }
    }

    public function changeAdminPassword(Request $request, $id)
    {
        $admin = $this->authenticate($request);
        if (!$admin) return response()->json(['success' => false, 'message' => 'Unauthorized.'], 401);

        try {
            $request->validate([
                'old_password' => 'required|string',
                'new_password' => [
                    'required', 'min:8',
                    'regex:/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[!@#$%^&*(),.?":{}|<>])[A-Za-z\d!@#$%^&*(),.?":{}|<>]+$/',
                ],
            ], [
                'new_password.min'   => 'New password must be at least 8 characters.',
                'new_password.regex' => 'New password must contain uppercase, lowercase, number, and special character.',
            ]);
        } catch (\Illuminate\Validation\ValidationException $e) {
            $errors     = $e->errors();
            $firstError = reset($errors);
            $message    = is_array($firstError) ? $firstError[0] : $firstError;
            return response()->json(['success' => false, 'message' => $message], 422);
        }

        $target = DB::table('admin_info')->where('id', $id)->first();
        if (!$target) return response()->json(['success' => false, 'message' => 'Admin not found.'], 404);

        if (!Hash::check($request->old_password, $target->admin_password_hash)) {
            return response()->json(['success' => false, 'message' => 'Old password is incorrect.'], 400);
        }

        DB::table('admin_info')->where('id', $id)->update([
            'admin_password_hash' => Hash::make($request->new_password),
        ]);

        // ── AUDIT LOG ────────────────────────────────────────────────────────
        AdminAuditLog::record(
            admin:          $admin,
            action:         AdminAuditLog::ACTION_CHANGE_ADMIN_PW,
            targetType:     'admin',
            targetId:       (string) $id,
            targetUsername: $target->admin_username,
            changes:        ['before' => ['password' => '[hidden]'], 'after' => ['password' => '[hidden — changed]']],
            details:        ['admin_id' => (string) $id, 'changed_by' => $admin->admin_username]
        );

        return response()->json(['success' => true, 'message' => 'Password changed.']);
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  AUDIT LOG VIEWER
    // ══════════════════════════════════════════════════════════════════════════

    /**
     * GET /admin/audit-logs
     * Params: admin_id, target_type, action, page, per_page
     */
    public function getAuditLogs(Request $request)
    {
        $admin = $this->authenticate($request);
        if (!$admin) return response()->json(['success' => false, 'message' => 'Unauthorized.'], 401);

        try {
            $query = DB::connection('mongodb')->table('admin_audit_logs');

            if ($request->filled('admin_id'))    $query->where('admin_id', $request->admin_id);
            if ($request->filled('target_type')) $query->where('target_type', $request->target_type);
            if ($request->filled('action'))      $query->where('action', $request->action);

            $perPage = (int) $request->get('per_page', 20);
            $page    = (int) $request->get('page', 1);
            $total   = $query->count();

            $logs = $query->orderBy('created_at', 'desc')
                ->skip(($page - 1) * $perPage)
                ->limit($perPage)
                ->get();

            return response()->json([
                'success'     => true,
                'total'       => $total,
                'page'        => $page,
                'per_page'    => $perPage,
                'total_pages' => (int) ceil($total / max($perPage, 1)),
                'logs'        => $logs,
            ]);

        } catch (\Exception $e) {
            return response()->json(['success' => false, 'message' => $e->getMessage()], 500);
        }
    }
}
