<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

return new class extends Migration
{
    public function up(): void
    {
        // ── admin_info ──────────────────────────────────────────────────────
        Schema::create('admin_info', function (Blueprint $table) {
            $table->id();
            $table->string('admin_username', 50)->unique();
            $table->string('admin_password_hash', 255);
            $table->string('admin_image', 255)->nullable();
            $table->string('admin_sex', 10)->nullable();
            $table->string('session_token', 255)->nullable()->index();
            $table->timestamp('last_login')->nullable();
            $table->datetime('date_added')->useCurrent();
        });

        // Seed the ONE default admin (cannot be changed via the app)
        DB::table('admin_info')->insert([
            'admin_username'      => 'starbooks_admin',
            'admin_password_hash' => Hash::make('Admin@Starbooks2025'),
            'admin_image'         => null,
            'admin_sex'           => 'Male',
            'date_added'          => now(),
        ]);

        // ── quiz_difficulty_settings ────────────────────────────────────────
        Schema::create('quiz_difficulty_settings', function (Blueprint $table) {
            $table->id();
            $table->enum('difficulty_level', ['Easy', 'Average', 'Difficult'])->unique();
            $table->integer('points_per_qn')->default(10);
            $table->integer('num_questions')->default(10);
            $table->integer('time_per_qn')->default(15);
            $table->timestamp('updated_at')->useCurrent()->useCurrentOnUpdate();
        });

        // Seed default difficulty settings
        DB::table('quiz_difficulty_settings')->insert([
            ['difficulty_level' => 'Easy',      'points_per_qn' => 10, 'num_questions' => 10, 'time_per_qn' => 15],
            ['difficulty_level' => 'Average',   'points_per_qn' => 15, 'num_questions' => 10, 'time_per_qn' => 20],
            ['difficulty_level' => 'Difficult', 'points_per_qn' => 20, 'num_questions' => 10, 'time_per_qn' => 25],
        ]);
    }

    public function down(): void
    {
        Schema::dropIfExists('quiz_difficulty_settings');
        Schema::dropIfExists('admin_info');
    }
};
