import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/utils/media_files.dart';
import 'package:frontend/features/chat/widgets/chat_input_bar.dart';
import 'package:frontend/features/notification/providers/notification_provider.dart';

NotificationRecord _notification(String title, {String message = 'hi', bool isRead = true}) =>
    NotificationRecord.fromJson({
      'notification_id': 1,
      'title': title,
      'message': message,
      'is_read': isRead,
      'created_at': '2026-11-27T08:00:00Z',
      'recipient': {'name': 'Me', 'email': ''},
    });

void main() {
  group('chat composer', () {
    Future<double> boxHeight(WidgetTester tester, String text) async {
      final controller = TextEditingController(text: text);
      addTearDown(controller.dispose);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: ChatInputBar(controller: controller, onSend: () {}, sending: false, onAttachPhoto: () {}),
        ),
      ));
      return tester.getSize(find.byType(ChatInputBar)).height;
    }

    testWidgets('stays one line tall when empty, not the whole screen', (tester) async {
      // An aligned Container under bottomNavigationBar once grew to fill the page.
      expect(await boxHeight(tester, ''), lessThan(90));
    });

    testWidgets('grows with the text, up to five lines', (tester) async {
      final one = await boxHeight(tester, 'hello');
      final three = await boxHeight(tester, 'a\nb\nc');
      final ten = await boxHeight(tester, List.filled(10, 'line').join('\n'));
      expect(three, greaterThan(one));
      expect(ten, greaterThan(three));
      expect(ten, lessThan(200), reason: 'capped at five lines, then it scrolls');
    });
  });

  group('notification filter', () {
    test('sorts by the title the server gives', () {
      expect(_notification('New Offer').category, NotificationFilter.offers);
      expect(_notification('Offer Update').category, NotificationFilter.offers);
      expect(_notification('Order Update').category, NotificationFilter.orders);
      expect(_notification('Delivered').category, NotificationFilter.orders);
      expect(_notification('New Review').category, NotificationFilter.reviews);
      expect(_notification('New Message').category, NotificationFilter.messages);
      // From before order events had their own title.
      expect(_notification('New Message', message: 'Order #12 placed: 5 kg').category, NotificationFilter.orders);
    });

    test('All and Unread', () {
      expect(NotificationFilter.all.matches(_notification('New Offer')), isTrue);
      expect(NotificationFilter.unread.matches(_notification('New Offer', isRead: false)), isTrue);
      expect(NotificationFilter.unread.matches(_notification('New Offer')), isFalse);
      expect(NotificationFilter.offers.matches(_notification('New Review')), isFalse);
    });
  });

  test('videos are told apart by extension, presigned query ignored', () {
    expect(isVideoSource('https://b.s3.amazonaws.com/chats/x.mp4?X-Amz-Signature=abc'), isTrue);
    expect(isVideoSource('/data/user/0/cache/clip.MOV'), isTrue);
    expect(isVideoSource('https://b.s3.amazonaws.com/chats/x.jpg?v=1.mp4'), isFalse);
    expect(uploadContentType('a.mov').mimeType, 'video/quicktime');
    expect(uploadContentType('a.mp4').mimeType, 'video/mp4');
    expect(uploadContentType('a.png').mimeType, 'image/png');
  });
}
