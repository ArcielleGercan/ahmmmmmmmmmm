// Widget tests for Starbooks Whiz Challenge
//
// Tests the startup routing logic of MyApp based on session state.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_projects/main.dart';
import 'package:flutter_projects/homepage.dart';
import 'package:flutter_projects/splash_screen.dart';

void main() {
  UserProfile fakeProfile() => UserProfile(
    id: 'test_user_1',
    username: 'TestUser',
    school: 'Test School',
    age: '12',
    category: 'Student',
    sex: 'Male',
    region: 'NCR',
    province: 'Metro Manila',
    city: 'Quezon City',
    avatar: 'assets/images-avatars/Adventurer.png',
    stars: 0,
  );

  group('MyApp routing', () {
    testWidgets(
      'shows SplashScreen when there is no active session',
          (WidgetTester tester) async {
        await tester.pumpWidget(const MyApp(initialProfile: null));
        await tester.pump();

        expect(find.byType(SplashScreen), findsOneWidget);
        expect(find.byType(HomePage),     findsNothing);
      },
    );

    testWidgets(
      'shows HomePage when a valid session is restored (refresh while logged in)',
          (WidgetTester tester) async {
        await tester.pumpWidget(MyApp(initialProfile: fakeProfile()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(HomePage),     findsOneWidget);
        expect(find.byType(SplashScreen), findsNothing);
      },
    );
  });
}