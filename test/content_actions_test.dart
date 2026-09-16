import 'package:flutter_test/flutter_test.dart';
import 'package:ycomm_client/features/forum/content_actions.dart';

void main() {
  const owner = {'id': 'owner', 'role': 'owner', 'state': 'active'};
  const admin = {'id': 'admin', 'role': 'admin', 'state': 'active'};
  const author = {'id': 'author', 'role': 'member', 'state': 'active'};
  const other = {'id': 'other', 'role': 'member', 'state': 'active'};

  group('content permissions', () {
    test('staff can moderate topics and delete other replies', () {
      expect(canModerateTopics(admin), isTrue);
      expect(canModerateTopics(owner), isTrue);
      expect(canDeleteReply(admin, 'other'), isTrue);
      expect(canDeleteReply(owner, null), isTrue);
    });

    test('authors can delete and edit their own content', () {
      expect(canDeleteTopic(author, 'author'), isTrue);
      expect(canDeleteReply(author, 'author'), isTrue);
      expect(canEditReply(author, 'author'), isTrue);
      expect(canEditReply(admin, 'author'), isFalse);
      expect(canDeleteTopic(other, 'author'), isFalse);
    });

    test('resource withdrawal is limited to author or owner', () {
      expect(canWithdrawResource(author, 'author'), isTrue);
      expect(canWithdrawResource(owner, 'author'), isTrue);
      expect(canWithdrawResource(admin, 'author'), isFalse);
      expect(canWithdrawResource(other, 'author'), isFalse);
    });

    test('a dialog authorization expires after an account change', () {
      final guard = ContentIdentity.capture(author);
      expect(guard.matches(author), isTrue);
      expect(guard.matches(other), isFalse);
      expect(guard.matches(null), isFalse);
      expect(guard.matches({...author, 'state': 'banned'}), isFalse);
    });

    test('inactive and unknown states cannot mutate content', () {
      for (final state in [null, 'banned', 'muted', 'unknown']) {
        final user = {...owner, 'state': state};
        expect(canModerateTopics(user), isFalse);
        expect(canDeleteTopic(user, 'owner'), isFalse);
        expect(canDeleteReply(user, 'owner'), isFalse);
        expect(canEditReply(user, 'owner'), isFalse);
        expect(canWithdrawResource(user, 'owner'), isFalse);
      }
    });
  });
}
