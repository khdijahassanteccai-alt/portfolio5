import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'package:doctor/database/database_helper.dart';

/// Opens a fresh in-memory SQLite database with the full app schema,
/// then injects it into the DatabaseHelper singleton so all CRUD methods
/// operate on this isolated database instead of the real file on disk.
Future<Database> openTestDb() async {
  sqfliteFfiInit();
  final db = await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 9,
      onCreate: _createSchema,
    ),
  );
  DatabaseHelper.setDatabaseForTesting(db);
  return db;
}

Future<void> _createSchema(Database db, int version) async {
  await db.execute('''
    CREATE TABLE doctors (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      specialty TEXT,
      phone TEXT,
      clinicName TEXT,
      address TEXT DEFAULT '',
      username TEXT UNIQUE NOT NULL,
      password TEXT NOT NULL,
      createdAt TEXT NOT NULL
    )
  ''');

  await db.execute('''
    CREATE TABLE patients (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      doctorId INTEGER NOT NULL DEFAULT 1,
      name TEXT NOT NULL,
      phone TEXT,
      birthDate TEXT,
      gender TEXT,
      bloodType TEXT,
      address TEXT,
      notes TEXT,
      createdAt TEXT NOT NULL,
      chronicDiseases TEXT DEFAULT '',
      drugAllergies TEXT DEFAULT '',
      previousSurgeries TEXT DEFAULT '',
      currentMedications TEXT DEFAULT '',
      medicalHistory TEXT DEFAULT ''
    )
  ''');

  await db.execute('''
    CREATE TABLE appointments (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      doctorId INTEGER NOT NULL DEFAULT 1,
      patientId INTEGER NOT NULL,
      patientName TEXT NOT NULL,
      date TEXT NOT NULL,
      time TEXT NOT NULL,
      type TEXT,
      status TEXT DEFAULT 'pending',
      notes TEXT,
      createdAt TEXT NOT NULL
    )
  ''');

  await db.execute('''
    CREATE TABLE prescriptions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      doctorId INTEGER NOT NULL DEFAULT 1,
      patientId INTEGER NOT NULL,
      patientName TEXT NOT NULL,
      date TEXT NOT NULL,
      diagnosis TEXT,
      medications TEXT,
      notes TEXT,
      createdAt TEXT NOT NULL
    )
  ''');

  await db.execute('''
    CREATE TABLE invoices (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      doctorId INTEGER NOT NULL DEFAULT 1,
      patientId INTEGER NOT NULL,
      patientName TEXT NOT NULL,
      date TEXT NOT NULL,
      items TEXT NOT NULL,
      total REAL NOT NULL DEFAULT 0,
      status TEXT DEFAULT 'unpaid',
      notes TEXT,
      createdAt TEXT NOT NULL
    )
  ''');

  await db.execute('''
    CREATE TABLE queue (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      doctorId INTEGER NOT NULL DEFAULT 1,
      patientName TEXT NOT NULL,
      patientId INTEGER,
      sequenceNumber INTEGER NOT NULL,
      status TEXT DEFAULT 'waiting',
      date TEXT NOT NULL,
      createdAt TEXT NOT NULL
    )
  ''');

  await db.execute('''
    CREATE TABLE patient_images (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      doctorId INTEGER NOT NULL DEFAULT 1,
      patientId INTEGER NOT NULL,
      imagePath TEXT NOT NULL,
      category TEXT NOT NULL DEFAULT 'أخرى',
      description TEXT DEFAULT '',
      createdAt TEXT NOT NULL
    )
  ''');

  await db.execute('''
    CREATE TABLE expenses (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      doctorId INTEGER NOT NULL DEFAULT 1,
      category TEXT NOT NULL,
      amount REAL NOT NULL,
      description TEXT DEFAULT '',
      date TEXT NOT NULL,
      createdAt TEXT NOT NULL
    )
  ''');

  await db.execute('''
    CREATE TABLE visits (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      doctorId INTEGER NOT NULL DEFAULT 1,
      patientId INTEGER NOT NULL,
      visitDate TEXT NOT NULL,
      visitType TEXT NOT NULL DEFAULT 'فحص عام',
      notes TEXT DEFAULT '',
      createdAt TEXT NOT NULL
    )
  ''');

  await db.execute('''
    CREATE TABLE medicines (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      doctorId INTEGER NOT NULL DEFAULT 1,
      name TEXT NOT NULL
    )
  ''');

  const defaultMeds = [
    'Paracetamol (باراسيتامول)',
    'Amoxicillin (أموكسيسيلين)',
    'Omeprazole (أوميبرازول)',
    'Ibuprofen (إيبوبروفين)',
    'Azithromycin (أزيثروميسين)',
  ];
  for (final name in defaultMeds) {
    await db.insert('medicines', {'doctorId': 1, 'name': name});
  }

  // Default doctor with id = 1
  await db.insert('doctors', {
    'name': 'دكتور تجريبي',
    'specialty': 'طب عام',
    'phone': '07700000000',
    'clinicName': 'عيادة الاختبار',
    'username': '__test__',
    'password': 'test123',
    'createdAt': DateTime.now().toIso8601String(),
  });
}
