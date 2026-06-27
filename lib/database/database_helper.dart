import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/patient.dart';
import '../models/appointment.dart';
import '../models/prescription.dart';
import '../models/doctor.dart';
import '../models/invoice.dart';
import '../models/queue_entry.dart';
import '../models/patient_image.dart';
import '../models/expense.dart';
import '../models/visit.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  // Injects a pre-built database so unit tests can use an in-memory instance
  // without going through the real file-path logic or path_provider.
  static void setDatabaseForTesting(Database db) => _database = db;

  Future<Database> _initDatabase() async {
    final String path;
    if (Platform.isWindows || Platform.isLinux) {
      // getDatabasesPath() points to the install dir on desktop (read-only).
      // getApplicationSupportDirectory() → %AppData%\Roaming\<app> on Windows,
      // ~/.local/share/<app> on Linux — always writable without admin rights.
      final dir = await getApplicationSupportDirectory();
      path = join(dir.path, 'clinic.db');
    } else {
      // Android/iOS: standard sqflite path (/data/data/<pkg>/databases/)
      path = join(await getDatabasesPath(), 'clinic.db');
    }
    return await openDatabase(
      path,
      version: 9,
      onCreate: _createTables,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createTables(Database db, int version) async {
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

    // Pre-populate common medicines
    const defaultMeds = [
      'Paracetamol (باراسيتامول)',
      'Amoxicillin (أموكسيسيلين)',
      'Omeprazole (أوميبرازول)',
      'Ibuprofen (إيبوبروفين)',
      'Azithromycin (أزيثروميسين)',
      'Metformin (ميتفورمين)',
      'Amlodipine (أملوديبين)',
      'Atorvastatin (أتورفاستاتين)',
      'Ciprofloxacin (سيبروفلوكساسين)',
      'Metronidazole (ميترونيدازول)',
      'Dexamethasone (ديكساميثازون)',
      'Cetirizine (سيتيريزين)',
      'Vitamin C (فيتامين سي)',
      'Vitamin D3 (فيتامين د3)',
      'Iron (حديد)',
      'Calcium (كالسيوم)',
      'Losartan (لوسارتان)',
      'Pantoprazole (بانتوبرازول)',
      'Clopidogrel (كلوبيدوغريل)',
      'Aspirin (أسبرين)',
    ];
    for (final name in defaultMeds) {
      await db.insert('medicines', {'doctorId': 1, 'name': name});
    }

    // Insert default doctor
    await db.insert('doctors', {
      'name': 'الدكتور',
      'specialty': 'طب عام',
      'phone': '',
      'clinicName': 'عيادتي',
      'username': 'doctor',
      'password': '123456',
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Create doctors table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS doctors (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          specialty TEXT,
          phone TEXT,
          clinicName TEXT,
          username TEXT UNIQUE NOT NULL,
          password TEXT NOT NULL,
          createdAt TEXT NOT NULL
        )
      ''');

      // Migrate existing data with default doctor
      await db.insert('doctors', {
        'name': 'الدكتور',
        'specialty': 'طب عام',
        'phone': '',
        'clinicName': 'عيادتي',
        'username': 'doctor',
        'password': '123456',
        'createdAt': DateTime.now().toIso8601String(),
      });

      // Add doctorId to existing tables (SQLite doesn't support IF NOT EXISTS for columns)
      try {
        await db.execute(
            'ALTER TABLE patients ADD COLUMN doctorId INTEGER NOT NULL DEFAULT 1');
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE appointments ADD COLUMN doctorId INTEGER NOT NULL DEFAULT 1');
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE prescriptions ADD COLUMN doctorId INTEGER NOT NULL DEFAULT 1');
      } catch (_) {}

      // Create invoices table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS invoices (
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
    }

    if (oldVersion < 3) {
      // Add medical-record columns to existing patients rows
      for (final col in [
        "chronicDiseases TEXT DEFAULT ''",
        "drugAllergies TEXT DEFAULT ''",
        "previousSurgeries TEXT DEFAULT ''",
        "currentMedications TEXT DEFAULT ''",
        "medicalHistory TEXT DEFAULT ''",
      ]) {
        try {
          await db.execute('ALTER TABLE patients ADD COLUMN $col');
        } catch (_) {}
      }
    }

    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS queue (
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
    }

    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS patient_images (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          doctorId INTEGER NOT NULL DEFAULT 1,
          patientId INTEGER NOT NULL,
          imagePath TEXT NOT NULL,
          category TEXT NOT NULL DEFAULT 'أخرى',
          description TEXT DEFAULT '',
          createdAt TEXT NOT NULL
        )
      ''');
    }

    if (oldVersion < 6) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS expenses (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          doctorId INTEGER NOT NULL DEFAULT 1,
          category TEXT NOT NULL,
          amount REAL NOT NULL,
          description TEXT DEFAULT '',
          date TEXT NOT NULL,
          createdAt TEXT NOT NULL
        )
      ''');
    }

    if (oldVersion < 7) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS visits (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          doctorId INTEGER NOT NULL DEFAULT 1,
          patientId INTEGER NOT NULL,
          visitDate TEXT NOT NULL,
          visitType TEXT NOT NULL DEFAULT 'فحص عام',
          notes TEXT DEFAULT '',
          createdAt TEXT NOT NULL
        )
      ''');
    }

    if (oldVersion < 8) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS medicines (
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
        'Metformin (ميتفورمين)',
        'Amlodipine (أملوديبين)',
        'Atorvastatin (أتورفاستاتين)',
        'Ciprofloxacin (سيبروفلوكساسين)',
        'Metronidazole (ميترونيدازول)',
        'Dexamethasone (ديكساميثازون)',
        'Cetirizine (سيتيريزين)',
        'Vitamin C (فيتامين سي)',
        'Vitamin D3 (فيتامين د3)',
        'Iron (حديد)',
        'Calcium (كالسيوم)',
        'Losartan (لوسارتان)',
        'Pantoprazole (بانتوبرازول)',
        'Clopidogrel (كلوبيدوغريل)',
        'Aspirin (أسبرين)',
      ];
      for (final name in defaultMeds) {
        try {
          await db.insert('medicines', {'doctorId': 1, 'name': name});
        } catch (_) {}
      }
    }

    if (oldVersion < 9) {
      try {
        await db.execute(
            "ALTER TABLE doctors ADD COLUMN address TEXT DEFAULT ''");
      } catch (_) {}
    }
  }

  // ─── Doctors ──────────────────────────────────────────────────────────────────

  Future<int> insertDoctor(Doctor doctor) async {
    final db = await database;
    final map = doctor.toMap()..remove('id');
    return await db.insert('doctors', map);
  }

  Future<int> updateDoctor(Doctor doctor) async {
    final db = await database;
    return await db.update('doctors', doctor.toMap(),
        where: 'id = ?', whereArgs: [doctor.id]);
  }

  Future<Doctor?> getDoctorById(int id) async {
    final db = await database;
    final maps = await db.query('doctors', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Doctor.fromMap(maps.first);
  }

  Future<Doctor?> getDoctorByUsername(String username) async {
    final db = await database;
    final maps =
        await db.query('doctors', where: 'username = ?', whereArgs: [username]);
    if (maps.isEmpty) return null;
    return Doctor.fromMap(maps.first);
  }

  Future<Doctor?> getDoctorByCredentials(
      String username, String password) async {
    final db = await database;
    final maps = await db.query('doctors',
        where: 'username = ? AND password = ?',
        whereArgs: [username, password]);
    if (maps.isEmpty) return null;
    return Doctor.fromMap(maps.first);
  }

  Future<bool> usernameExists(String username) async {
    final db = await database;
    final maps = await db
        .query('doctors', where: 'username = ?', whereArgs: [username]);
    return maps.isNotEmpty;
  }

  Future<List<Doctor>> getAllDoctors() async {
    final db = await database;
    final maps = await db.query('doctors', orderBy: 'name ASC');
    return maps.map((m) => Doctor.fromMap(m)).toList();
  }

  // ─── Patients ────────────────────────────────────────────────────────────────

  Future<int> insertPatient(Patient patient, {required int doctorId}) async {
    final db = await database;
    final map = patient.toMap()..remove('id');
    map['doctorId'] = doctorId;
    return await db.insert('patients', map);
  }

  Future<int> updatePatient(Patient patient) async {
    final db = await database;
    return await db.update('patients', patient.toMap(),
        where: 'id = ?', whereArgs: [patient.id]);
  }

  Future<int> deletePatient(int id) async {
    final db = await database;
    await db.delete('appointments', where: 'patientId = ?', whereArgs: [id]);
    await db.delete('prescriptions', where: 'patientId = ?', whereArgs: [id]);
    await db.delete('invoices', where: 'patientId = ?', whereArgs: [id]);
    return await db.delete('patients', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Patient>> getAllPatients({required int doctorId}) async {
    final db = await database;
    final maps = await db.query('patients',
        where: 'doctorId = ?',
        whereArgs: [doctorId],
        orderBy: 'createdAt DESC');
    return maps.map((m) => Patient.fromMap(m)).toList();
  }

  Future<Patient?> getPatientById(int id) async {
    final db = await database;
    final maps = await db.query('patients', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Patient.fromMap(maps.first);
  }

  Future<List<Patient>> searchPatients(String query,
      {required int doctorId}) async {
    final db = await database;
    final maps = await db.query(
      'patients',
      where:
          '(name LIKE ? OR phone LIKE ? OR CAST(id AS TEXT) LIKE ?) AND doctorId = ?',
      whereArgs: ['%$query%', '%$query%', '%$query%', doctorId],
      orderBy: 'name ASC',
    );
    return maps.map((m) => Patient.fromMap(m)).toList();
  }

  // ─── Appointments ─────────────────────────────────────────────────────────────

  Future<int> insertAppointment(Appointment appointment,
      {required int doctorId}) async {
    final db = await database;
    final map = appointment.toMap()..remove('id');
    map['doctorId'] = doctorId;
    return await db.insert('appointments', map);
  }

  Future<int> updateAppointment(Appointment appointment) async {
    final db = await database;
    return await db.update('appointments', appointment.toMap(),
        where: 'id = ?', whereArgs: [appointment.id]);
  }

  Future<int> deleteAppointment(int id) async {
    final db = await database;
    return await db
        .delete('appointments', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Appointment>> getAllAppointments(
      {required int doctorId}) async {
    final db = await database;
    final maps = await db.query('appointments',
        where: 'doctorId = ?',
        whereArgs: [doctorId],
        orderBy: 'date DESC, time ASC');
    return maps.map((m) => Appointment.fromMap(m)).toList();
  }

  Future<List<Appointment>> getAppointmentsByPatient(int patientId) async {
    final db = await database;
    final maps = await db.query('appointments',
        where: 'patientId = ?',
        whereArgs: [patientId],
        orderBy: 'date DESC, time ASC');
    return maps.map((m) => Appointment.fromMap(m)).toList();
  }

  Future<List<Appointment>> getAppointmentsByDate(String date,
      {required int doctorId}) async {
    final db = await database;
    final maps = await db.query('appointments',
        where: 'date = ? AND doctorId = ?',
        whereArgs: [date, doctorId],
        orderBy: 'time ASC');
    return maps.map((m) => Appointment.fromMap(m)).toList();
  }

  Future<int> updateAppointmentStatus(int id, String status) async {
    final db = await database;
    return await db.update('appointments', {'status': status},
        where: 'id = ?', whereArgs: [id]);
  }

  // ─── Prescriptions ────────────────────────────────────────────────────────────

  Future<int> insertPrescription(Prescription prescription,
      {required int doctorId}) async {
    final db = await database;
    final map = prescription.toDbMap()..remove('id');
    map['doctorId'] = doctorId;
    return await db.insert('prescriptions', map);
  }

  Future<int> deletePrescription(int id) async {
    final db = await database;
    return await db
        .delete('prescriptions', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Prescription>> getAllPrescriptions(
      {required int doctorId}) async {
    final db = await database;
    final maps = await db.query('prescriptions',
        where: 'doctorId = ?',
        whereArgs: [doctorId],
        orderBy: 'date DESC');
    return maps.map((m) => Prescription.fromMap(m)).toList();
  }

  Future<List<Prescription>> getPrescriptionsByPatient(int patientId) async {
    final db = await database;
    final maps = await db.query('prescriptions',
        where: 'patientId = ?',
        whereArgs: [patientId],
        orderBy: 'date DESC');
    return maps.map((m) => Prescription.fromMap(m)).toList();
  }

  // ─── Invoices ─────────────────────────────────────────────────────────────────

  Future<int> insertInvoice(Invoice invoice) async {
    final db = await database;
    final map = invoice.toDbMap()..remove('id');
    return await db.insert('invoices', map);
  }

  Future<int> updateInvoiceStatus(int id, String status) async {
    final db = await database;
    return await db.update('invoices', {'status': status},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteInvoice(int id) async {
    final db = await database;
    return await db.delete('invoices', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Invoice>> getAllInvoices({required int doctorId}) async {
    final db = await database;
    final maps = await db.query('invoices',
        where: 'doctorId = ?',
        whereArgs: [doctorId],
        orderBy: 'date DESC');
    return maps.map((m) => Invoice.fromMap(m)).toList();
  }

  Future<List<Invoice>> getInvoicesByPatient(int patientId) async {
    final db = await database;
    final maps = await db.query('invoices',
        where: 'patientId = ?',
        whereArgs: [patientId],
        orderBy: 'date DESC');
    return maps.map((m) => Invoice.fromMap(m)).toList();
  }

  // ─── Stats ────────────────────────────────────────────────────────────────────

  Future<Map<String, int>> getStats({required int doctorId}) async {
    final db = await database;
    final patients = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM patients WHERE doctorId = ?', [doctorId])) ?? 0;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final todayAppts = Sqflite.firstIntValue(await db.rawQuery(
          "SELECT COUNT(*) FROM appointments WHERE date = ? AND doctorId = ?",
          [today, doctorId])) ?? 0;
    final pending = Sqflite.firstIntValue(await db.rawQuery(
          "SELECT COUNT(*) FROM appointments WHERE status = 'pending' AND doctorId = ?",
          [doctorId])) ?? 0;
    final prescriptions = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM prescriptions WHERE doctorId = ?',
          [doctorId])) ?? 0;
    final invoices = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM invoices WHERE doctorId = ?',
          [doctorId])) ?? 0;
    return {
      'patients': patients,
      'todayAppointments': todayAppts,
      'pendingAppointments': pending,
      'prescriptions': prescriptions,
      'invoices': invoices,
    };
  }

  Future<double> getTotalRevenue({required int doctorId}) async {
    final db = await database;
    final result = await db.rawQuery(
      "SELECT COALESCE(SUM(total), 0) FROM invoices WHERE doctorId = ? AND status = 'paid'",
      [doctorId]);
    return (result.first.values.first as num?)?.toDouble() ?? 0.0;
  }

  Future<List<double>> getMonthlyRevenue(
      {required int doctorId, required int year}) async {
    final db = await database;
    return Future.wait(List.generate(12, (i) async {
      final m = (i + 1).toString().padLeft(2, '0');
      final r = await db.rawQuery(
        "SELECT COALESCE(SUM(total),0) FROM invoices "
        "WHERE doctorId=? AND status='paid' "
        "AND strftime('%Y',date)=? AND strftime('%m',date)=?",
        [doctorId, year.toString(), m]);
      return (r.first.values.first as num?)?.toDouble() ?? 0.0;
    }));
  }

  Future<List<Map<String, dynamic>>> getTopDiagnoses(
      {required int doctorId, int limit = 8}) async {
    final db = await database;
    final rows = await db.rawQuery(
      "SELECT diagnosis, COUNT(*) AS cnt FROM prescriptions "
      "WHERE doctorId=? AND diagnosis IS NOT NULL AND diagnosis!='' "
      "GROUP BY diagnosis ORDER BY cnt DESC LIMIT ?",
      [doctorId, limit]);
    return rows
        .map((r) => {'diagnosis': r['diagnosis'] as String, 'count': r['cnt'] as int})
        .toList();
  }

  Future<Map<String, List<int>>> getMonthlyStats(
      {required int doctorId, required int year}) async {
    final db = await database;
    final months = List<int>.generate(12, (i) => i + 1);

    Future<List<int>> queryMonthly(String table) async {
      return Future.wait(months.map((m) async {
        final monthStr = m.toString().padLeft(2, '0');
        final count = Sqflite.firstIntValue(await db.rawQuery(
              "SELECT COUNT(*) FROM $table WHERE doctorId = ? AND createdAt LIKE '$year-$monthStr%'",
              [doctorId])) ?? 0;
        return count;
      }));
    }

    return {
      'patients': await queryMonthly('patients'),
      'appointments': await queryMonthly('appointments'),
      'prescriptions': await queryMonthly('prescriptions'),
    };
  }

  // ─── Queue ────────────────────────────────────────────────────────────────────

  static String get _today => DateTime.now().toIso8601String().substring(0, 10);

  /// Returns today's next available sequence number (1-based, resets daily).
  Future<int> _nextSequenceNumber(
      {required int doctorId, required String date}) async {
    final db = await database;
    final result = await db.rawQuery(
        'SELECT MAX(sequenceNumber) FROM queue WHERE doctorId = ? AND date = ?',
        [doctorId, date]);
    final max = result.first.values.first as int?;
    return (max ?? 0) + 1;
  }

  /// Adds a new entry to today's queue. Returns the created entry.
  Future<QueueEntry> addToQueue({
    required int doctorId,
    required String patientName,
    int? patientId,
  }) async {
    final db = await database;
    final date = _today;
    final seq = await _nextSequenceNumber(doctorId: doctorId, date: date);
    final now = DateTime.now().toIso8601String();
    final entry = QueueEntry(
      doctorId: doctorId,
      patientName: patientName,
      patientId: patientId,
      sequenceNumber: seq,
      date: date,
      createdAt: now,
    );
    final id = await db.insert('queue', entry.toMap());
    return QueueEntry(
      id: id,
      doctorId: entry.doctorId,
      patientName: entry.patientName,
      patientId: entry.patientId,
      sequenceNumber: entry.sequenceNumber,
      date: entry.date,
      createdAt: entry.createdAt,
    );
  }

  /// Returns all queue entries for today, ordered by sequence number.
  Future<List<QueueEntry>> getQueueForToday({required int doctorId}) async {
    final db = await database;
    final maps = await db.query(
      'queue',
      where: 'doctorId = ? AND date = ?',
      whereArgs: [doctorId, _today],
      orderBy: 'sequenceNumber ASC',
    );
    return maps.map(QueueEntry.fromMap).toList();
  }

  /// Count of patients currently with status='waiting' today.
  Future<int> getWaitingCount({required int doctorId}) async {
    final db = await database;
    return Sqflite.firstIntValue(await db.rawQuery(
          "SELECT COUNT(*) FROM queue WHERE doctorId = ? AND date = ? AND status = 'waiting'",
          [doctorId, _today])) ??
        0;
  }

  /// Updates the status of a single queue entry.
  Future<void> updateQueueStatus(
      {required int id, required String status}) async {
    final db = await database;
    await db.update('queue', {'status': status},
        where: 'id = ?', whereArgs: [id]);
  }

  /// The entry currently being served (status='serving') today, if any.
  Future<QueueEntry?> getCurrentServing({required int doctorId}) async {
    final db = await database;
    final maps = await db.query(
      'queue',
      where: "doctorId = ? AND date = ? AND status = 'serving'",
      whereArgs: [doctorId, _today],
      limit: 1,
    );
    return maps.isEmpty ? null : QueueEntry.fromMap(maps.first);
  }

  /// Marks the current 'serving' patient as 'done', then promotes the next
  /// 'waiting' patient to 'serving'. Returns the newly serving entry or null.
  Future<QueueEntry?> callNextPatient({required int doctorId}) async {
    final db = await database;
    final date = _today;

    // Finish current serving patient
    await db.update(
      'queue',
      {'status': 'done'},
      where: "doctorId = ? AND date = ? AND status = 'serving'",
      whereArgs: [doctorId, date],
    );

    // Promote next waiting patient
    final waiting = await db.query(
      'queue',
      where: "doctorId = ? AND date = ? AND status = 'waiting'",
      whereArgs: [doctorId, date],
      orderBy: 'sequenceNumber ASC',
      limit: 1,
    );
    if (waiting.isEmpty) return null;

    final next = QueueEntry.fromMap(waiting.first);
    await db.update(
      'queue',
      {'status': 'serving'},
      where: 'id = ?',
      whereArgs: [next.id],
    );
    return next.copyWith(status: 'serving');
  }

  /// Removes a queue entry (e.g. patient left without being seen).
  Future<void> removeFromQueue({required int id}) async {
    final db = await database;
    await db.delete('queue', where: 'id = ?', whereArgs: [id]);
  }

  // ─── Patient Images ───────────────────────────────────────────────────────────

  Future<int> addPatientImage({
    required int patientId,
    required String imagePath,
    required String category,
    required String description,
    required int doctorId,
  }) async {
    final db = await database;
    return await db.insert('patient_images', {
      'patientId': patientId,
      'imagePath': imagePath,
      'category': category,
      'description': description,
      'createdAt': DateTime.now().toIso8601String(),
      'doctorId': doctorId,
    });
  }

  Future<List<PatientImage>> getPatientImages({
    required int patientId,
    required int doctorId,
  }) async {
    final db = await database;
    final maps = await db.query(
      'patient_images',
      where: 'patientId = ? AND doctorId = ?',
      whereArgs: [patientId, doctorId],
      orderBy: 'createdAt ASC',
    );
    return maps.map(PatientImage.fromMap).toList();
  }

  Future<void> deletePatientImage({required int id}) async {
    final db = await database;
    await db.delete('patient_images', where: 'id = ?', whereArgs: [id]);
  }

  // ─── Expenses ─────────────────────────────────────────────────────────────────

  Future<int> insertExpense({
    required int doctorId,
    required String category,
    required double amount,
    required String description,
    required String date,
  }) async {
    final db = await database;
    return await db.insert('expenses', {
      'doctorId': doctorId,
      'category': category,
      'amount': amount,
      'description': description,
      'date': date,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Expense>> getExpenses({required int doctorId}) async {
    final db = await database;
    final maps = await db.query(
      'expenses',
      where: 'doctorId = ?',
      whereArgs: [doctorId],
      orderBy: 'date DESC',
    );
    return maps.map(Expense.fromMap).toList();
  }

  Future<void> deleteExpense({required int id}) async {
    final db = await database;
    await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<double>> getMonthlyExpenses(
      {required int doctorId, required int year}) async {
    final db = await database;
    return Future.wait(List.generate(12, (i) async {
      final m = (i + 1).toString().padLeft(2, '0');
      final r = await db.rawQuery(
        "SELECT COALESCE(SUM(amount),0) FROM expenses "
        "WHERE doctorId=? AND date LIKE '$year-$m%'",
        [doctorId]);
      return (r.first.values.first as num?)?.toDouble() ?? 0.0;
    }));
  }

  Future<double> getTotalExpenses({required int doctorId}) async {
    final db = await database;
    final r = await db.rawQuery(
      "SELECT COALESCE(SUM(amount),0) FROM expenses WHERE doctorId=?",
      [doctorId]);
    return (r.first.values.first as num?)?.toDouble() ?? 0.0;
  }

  // ─── Daily stats (for MonthDetailScreen) ─────────────────────────────────────

  /// Returns one entry per day that has any data in the given month.
  /// Keys: day (String 'dd'), appointments, patients, revenue, expenses.
  Future<List<Map<String, dynamic>>> getDailyStats({
    required int doctorId,
    required int year,
    required int month,
  }) async {
    final db = await database;
    final prefix = '$year-${month.toString().padLeft(2, '0')}';

    final apptRows = await db.rawQuery(
      "SELECT strftime('%d',date) d,COUNT(*) n FROM appointments "
      "WHERE doctorId=? AND date LIKE '$prefix%' GROUP BY d",
      [doctorId]);
    final patRows = await db.rawQuery(
      "SELECT strftime('%d',createdAt) d,COUNT(*) n FROM patients "
      "WHERE doctorId=? AND createdAt LIKE '$prefix%' GROUP BY d",
      [doctorId]);
    final revRows = await db.rawQuery(
      "SELECT strftime('%d',date) d,COALESCE(SUM(total),0) t FROM invoices "
      "WHERE doctorId=? AND status='paid' AND date LIKE '$prefix%' GROUP BY d",
      [doctorId]);
    final expRows = await db.rawQuery(
      "SELECT strftime('%d',date) d,COALESCE(SUM(amount),0) t FROM expenses "
      "WHERE doctorId=? AND date LIKE '$prefix%' GROUP BY d",
      [doctorId]);

    final days = <String, Map<String, dynamic>>{};
    void ensure(String d) => days.putIfAbsent(
        d, () => {'day': d, 'appointments': 0, 'patients': 0, 'revenue': 0.0, 'expenses': 0.0});

    for (final r in apptRows) {
      final d = r['d'] as String;
      ensure(d);
      days[d]!['appointments'] = r['n'] as int;
    }
    for (final r in patRows) {
      final d = r['d'] as String;
      ensure(d);
      days[d]!['patients'] = r['n'] as int;
    }
    for (final r in revRows) {
      final d = r['d'] as String;
      ensure(d);
      days[d]!['revenue'] = (r['t'] as num).toDouble();
    }
    for (final r in expRows) {
      final d = r['d'] as String;
      ensure(d);
      days[d]!['expenses'] = (r['t'] as num).toDouble();
    }

    return days.values.toList()
      ..sort((a, b) => (a['day'] as String).compareTo(b['day'] as String));
  }

  // ─── Visits ───────────────────────────────────────────────────────────────────

  Future<int> insertVisit(Visit visit) async {
    final db = await database;
    return await db.insert('visits', visit.toMap());
  }

  Future<List<Visit>> getVisitsByPatient(int patientId) async {
    final db = await database;
    final maps = await db.query(
      'visits',
      where: 'patientId = ?',
      whereArgs: [patientId],
      orderBy: 'visitDate DESC',
    );
    return maps.map(Visit.fromMap).toList();
  }

  Future<void> deleteVisit({required int id}) async {
    final db = await database;
    await db.delete('visits', where: 'id = ?', whereArgs: [id]);
  }

  // ─── Medicines ────────────────────────────────────────────────────────────────

  Future<List<String>> getMedicines({required int doctorId}) async {
    final db = await database;
    final maps = await db.query(
      'medicines',
      where: 'doctorId = ?',
      whereArgs: [doctorId],
      orderBy: 'name ASC',
    );
    return maps.map((m) => m['name'] as String).toList();
  }

  Future<void> insertMedicine({
    required int doctorId,
    required String name,
  }) async {
    final db = await database;
    await db.insert('medicines', {'doctorId': doctorId, 'name': name});
  }

  Future<void> deleteMedicine({required int id}) async {
    final db = await database;
    await db.delete('medicines', where: 'id = ?', whereArgs: [id]);
  }

  // ─── Tomorrow appointment count ───────────────────────────────────────────────

  Future<int> getTomorrowAppointmentsCount({required int doctorId}) async {
    final db = await database;
    final tomorrow = DateTime.now().add(const Duration(days: 1))
        .toIso8601String()
        .substring(0, 10);
    final r = await db.rawQuery(
      "SELECT COUNT(*) FROM appointments WHERE doctorId=? AND date=?",
      [doctorId, tomorrow],
    );
    return (r.first.values.first as int?) ?? 0;
  }
}
