<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

class AddStarsToPlayerInfo extends Migration
{
    /**
     * Run the migrations.
     *
     * @return void
     */
    public function up()
    {
        // Add stars field to all existing players (default to 0)
        DB::connection('mongodb')
            ->table('player_info')
            ->whereNull('stars')
            ->update(['stars' => 0]);
    }

    /**
     * Reverse the migrations.
     *
     * @return void
     */
    public function down()
    {
        // Remove stars field from all players
        DB::connection('mongodb')
            ->table('player_info')
            ->update(['$unset' => ['stars' => '']]);
    }
}
