import 'package:flutter/material.dart';

// ── Brand colors ──────────────────────────────────────────────────────────────
const kNavy       = Color(0xFF1560BD);
const kNavy2      = Color(0xFF1252A8);
const kBlue       = Color(0xFF1A6FD4);
const kGold       = Color(0xFFF7C600);
const kGoldDark   = Color(0xFFE6B400);
const kEasy       = Color(0xFF22C55E);
const kAverage    = Color(0xFFF59E0B);
const kDifficult  = Color(0xFFEF4444);
const kPurple     = Color(0xFF656BE6);
const kOrange     = Color(0xFFE6833A);
const kCardBg     = Color(0x18FFFFFF);
const kCardBorder = Color(0x26FFFFFF);

// ── Rank medal colors ─────────────────────────────────────────────────────────
const kRank1 = Color(0xFFFFD700);
const kRank2 = Color(0xFFC0C0C0);
const kRank3 = Color(0xFFCD7F32);
const kRankN = Color(0xFFCBD5E1);

// ── Difficulty lists ──────────────────────────────────────────────────────────
const kGameDifficulties = ['EASY', 'AVERAGE', 'DIFFICULT'];
const kGameDifficultiesDisplay = ['Easy', 'Average', 'Difficult'];

// ── Puzzle categories ─────────────────────────────────────────────────────────
const kPuzzleCategories = [
  'Solar System', 'Scientists', 'Human Body',
  'Animals', 'Geometry', 'Starbooks',
];
const kPuzzleCategoriesShort = [
  'Solar', 'Sci.', 'Body', 'Anim.', 'Geo.', 'Books',
];

// ── Tier definitions (name, from, to, color) ──────────────────────────────────
const kTiers = [
  (name: 'Beginner', from: '0',     to: '49',  color: Color(0xFFCBD5E1)),
  (name: 'Bronze',   from: '50',    to: '99',  color: Color(0xFFCD7F32)),
  (name: 'Silver',   from: '100',   to: '249', color: Color(0xFFC0C0C0)),
  (name: 'Gold',     from: '250',   to: '499', color: Color(0xFFFFD700)),
  (name: 'Platinum', from: '500',   to: '999', color: Color(0xFFB8B0D0)),
  (name: 'Diamond',  from: '1000+', to: '',    color: Color(0xFF67E8F9)),
];

// ── Per-game accent colors ────────────────────────────────────────────────────
Color gameColor(String gameId) => switch (gameId) {
  'badges'            => kGold,
  'stars'             => kAverage,
  'whiz_memory_match' => kPurple,
  'whiz_puzzle'       => kOrange,
  _                   => kGold,
};
