// Mock data mirroring the prototype's tokens.jsx for the Today screen.

class Entry {
  const Entry({
    required this.id,
    required this.time,
    required this.type,
    required this.title,
    required this.detail,
    this.value, // num for money, String for move (e.g. "287 kcal"), null for rituals
    required this.sf,
  });

  final int id;
  final String time;
  final String type; // money | move | rituals
  final String title;
  final String detail;
  final Object? value;
  final String sf;

  int get hour => int.parse(time.split(':').first);
}

const todayEntries = <Entry>[
  Entry(id: 1, time: '06:42', type: 'rituals', title: 'Morning pages', detail: '15 min · journal', sf: 'book.closed.fill'),
  Entry(id: 2, time: '07:15', type: 'move', title: 'Run · Mission loop', detail: '4.8 km · 24:10', value: '287 kcal', sf: 'figure.run'),
  Entry(id: 3, time: '08:30', type: 'money', title: 'Verve Coffee', detail: 'Coffee · cortado', value: -5.75, sf: 'cup.and.saucer.fill'),
  Entry(id: 4, time: '09:10', type: 'rituals', title: 'Inbox zero', detail: '22 min · focus', sf: 'tray.fill'),
  Entry(id: 5, time: '12:40', type: 'money', title: 'Tartine', detail: 'Lunch · sandwich', value: -16.20, sf: 'fork.knife'),
  Entry(id: 6, time: '14:20', type: 'rituals', title: 'Spanish practice', detail: '18 min · Duolingo', sf: 'character.book.closed.fill'),
  Entry(id: 7, time: '17:45', type: 'move', title: 'Strength · push', detail: '42 min · gym', value: '312 kcal', sf: 'dumbbell.fill'),
  Entry(id: 8, time: '19:10', type: 'money', title: 'Whole Foods', detail: 'Groceries · dinner', value: -38.40, sf: 'basket.fill'),
  Entry(id: 9, time: '21:30', type: 'rituals', title: 'Read · Pachinko', detail: '28 min · 19 pgs', sf: 'books.vertical.fill'),
];
