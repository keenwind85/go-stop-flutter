import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_wallet.dart';

/// 현재 인증된 사용자 상태를 제공하는 StreamProvider
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// AuthService 인스턴스 Provider
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

/// Firebase Auth + Google Sign-In을 처리하는 서비스 클래스
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  /// 초기 지급 코인
  static const int initialCoin = 100;

  /// 현재 로그인된 사용자
  User? get currentUser => _auth.currentUser;

  /// 현재 사용자의 uid
  String? get uid => currentUser?.uid;

  /// 현재 사용자의 displayName
  String? get displayName => currentUser?.displayName;

  /// 로그인 상태 여부
  bool get isLoggedIn => currentUser != null;

  /// 로그인 상태 변화 스트림
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Google 로그인
  Future<UserCredential?> signInWithGoogle() async {
    try {
      UserCredential userCredential;

      if (kIsWeb) {
        // 웹: Firebase Auth의 signInWithPopup 사용
        final googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');

        userCredential = await _auth.signInWithPopup(googleProvider);
      } else {
        // 모바일: 기존 google_sign_in 사용
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

        if (googleUser == null) {
          // 사용자가 로그인 취소
          return null;
        }

        // Google 인증 정보 획득
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        // Firebase credential 생성
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        // Firebase 로그인
        userCredential = await _auth.signInWithCredential(credential);
      }

      final user = userCredential.user;

      if (user != null) {
        // 신규 유저인지 확인 후 코인 초기화
        final isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;
        if (isNewUser) {
          await _initializeNewUser(user);
        } else {
          // 기존 유저도 wallet이 없으면 초기화
          await _ensureUserWalletExists(user);
        }
      }

      print('[AuthService] Logged in: ${user?.displayName}');
      return userCredential;
    } catch (e) {
      print('[AuthService] Google sign-in error: $e');
      rethrow;
    }
  }

  /// 로그아웃
  Future<void> signOut() async {
    try {
      if (kIsWeb) {
        // 웹: Firebase Auth만 로그아웃
        await _auth.signOut();
      } else {
        // 모바일: google_sign_in도 함께 로그아웃
        await Future.wait([
          _auth.signOut(),
          _googleSignIn.signOut(),
        ]);
      }
      print('[AuthService] Signed out');
    } catch (e) {
      print('[AuthService] Sign-out error: $e');
      rethrow;
    }
  }

  /// 신규 유저 초기화 (프로필 + 지갑 + 일일 활동)
  Future<void> _initializeNewUser(User user) async {
    final userRef = _db.child('users/${user.uid}');

    final initialData = UserProfile(
      uid: user.uid,
      displayName: user.displayName ?? 'Unknown',
      avatar: user.photoURL,
      wallet: const UserWallet(coin: initialCoin, totalEarned: initialCoin),
      dailyActions: const DailyActions(),
    ).toJson();

    await userRef.set(initialData);
    print('[AuthService] New user initialized with $initialCoin coins: ${user.uid}');
  }

  /// 기존 유저 지갑 존재 확인 (없으면 초기화)
  Future<void> _ensureUserWalletExists(User user) async {
    final walletRef = _db.child('users/${user.uid}/wallet');
    final snapshot = await walletRef.get();

    if (!snapshot.exists) {
      final userRef = _db.child('users/${user.uid}');
      final initialData = UserProfile(
        uid: user.uid,
        displayName: user.displayName ?? 'Unknown',
        avatar: user.photoURL,
        wallet: const UserWallet(coin: initialCoin, totalEarned: initialCoin),
        dailyActions: const DailyActions(),
      ).toJson();

      await userRef.set(initialData);
      print('[AuthService] Existing user wallet initialized: ${user.uid}');
    }
  }

  /// 현재 유저 프로필 가져오기
  Future<UserProfile?> getCurrentUserProfile() async {
    final user = currentUser;
    if (user == null) return null;

    final snapshot = await _db.child('users/${user.uid}').get();
    if (!snapshot.exists) return null;

    return UserProfile.fromJson(
      user.uid,
      Map<String, dynamic>.from(snapshot.value as Map),
    );
  }

  /// 유저 프로필 스트림
  Stream<UserProfile?> getUserProfileStream() {
    final user = currentUser;
    if (user == null) return Stream.value(null);

    return _db.child('users/${user.uid}').onValue.map((event) {
      if (!event.snapshot.exists) return null;
      return UserProfile.fromJson(
        user.uid,
        Map<String, dynamic>.from(event.snapshot.value as Map),
      );
    });
  }
}
