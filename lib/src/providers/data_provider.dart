import 'package:flutter/foundation.dart';
import '../models/branch.dart';
import '../models/zone.dart';
import '../models/pond.dart';
import '../models/species.dart';
import '../models/fish_batch.dart';
import '../models/product.dart';
import '../models/employee.dart';
import '../models/task.dart';
import '../models/customer.dart';
import '../models/sale_order.dart';
import '../models/purchase_order.dart';
import '../models/supplier.dart';
import '../models/stock_receipt.dart';
import '../models/stock_issue.dart';
import '../models/stock_take.dart';
import '../models/payment_voucher.dart';
import '../models/sensor_reading.dart';
import '../models/water_standard.dart';
import '../models/disease_log.dart';
import '../models/treatment_log.dart';
import '../models/feeding_schedule.dart';
import '../models/crop_cycle.dart';
import '../models/equipment.dart';
import '../models/daily_log.dart';
import '../models/water_change_log.dart';
import '../models/size_measurement.dart';
import '../services/api_service.dart';

class DataProvider extends ChangeNotifier {
  final ApiService _api;
  DataProvider({ApiService? api}) : _api = api ?? ApiService();

  /// Set auth token so all API calls include Authorization header
  void setToken(String? token) => _api.setToken(token);

  /// Register a callback invoked when API returns 401 (token expired)
  set onUnauthorized(VoidCallback? cb) => _api.onUnauthorized = cb;

  bool _loading = false;
  bool get loading => _loading;

  // ── Data ──
  List<Branch> branches = [];
  List<Zone> zones = [];
  List<Pond> ponds = [];
  List<Species> species = [];
  List<FishBatch> fishBatches = [];
  List<Product> products = [];
  List<Employee> employees = [];
  List<Task> tasks = [];
  List<Customer> customers = [];
  List<SaleOrder> saleOrders = [];
  List<PurchaseOrder> purchaseOrders = [];
  List<Supplier> suppliers = [];
  List<StockReceipt> stockReceipts = [];
  List<StockIssue> stockIssues = [];
  List<StockTake> stockTakes = [];
  List<PaymentVoucher> paymentVouchers = [];
  List<SensorReading> sensorReadings = [];
  List<WaterStandard> waterStandards = [];
  List<DiseaseLog> diseaseLogs = [];
  List<TreatmentLog> treatmentLogs = [];
  List<FeedingSchedule> feedingSchedules = [];
  List<CropCycle> cropCycles = [];
  List<Equipment> equipmentList = [];
  List<DailyLog> dailyLogs = [];
  List<WaterChangeLog> waterChangeLogs = [];
  List<SizeMeasurement> sizeMeasurements = [];
  List<Map<String, dynamic>> notifications = [];
  List<Map<String, dynamic>> auditLogs = [];
  List<Map<String, dynamic>> harvests = [];
  List<Map<String, dynamic>> profitAnalysis = [];
  List<Map<String, dynamic>> supplierDebts = [];
  List<Map<String, dynamic>> feedingLogs = [];
  List<Map<String, dynamic>> mortalityLogs = [];
  List<Map<String, dynamic>> maintenanceLogs = [];
  List<Map<String, dynamic>> searchResults = [];
  Map<String, dynamic> dashboardData = {};

  // ── Dashboard ──
  Future<void> loadDashboard() async {
    try {
      final resp = await _api.get('/dashboard');
      if (resp.statusCode == 200 && resp.data != null) {
        dashboardData = resp.data as Map<String, dynamic>;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('loadDashboard error: $e');
    }
  }

  // ── Generic loader ──
  Future<void> loadAll() async {
    _loading = true;
    notifyListeners();
    try {
      final results = await Future.wait([
        _api.fetchList('branches'),
        _api.fetchList('zones'),
        _api.fetchList('ponds'),
        _api.fetchList('species'),
        _api.fetchList('fishbatches'),
        _api.fetchList('products'),
        _api.fetchList('employees'),
        _api.fetchList('tasks'),
        _api.fetchList('customers'),
        _api.fetchList('saleorders'),
        _api.fetchList('purchaseorders'),
        _api.fetchList('notifications'),
        _api.fetchList('suppliers'),
        _api.fetchList('stockreceipts'),
        _api.fetchList('stockissues'),
        _api.fetchList('stocktakes'),
        _api.fetchList('paymentvouchers'),
        _api.fetchList('sensorreadings'),
        _api.fetchList('waterstandards'),
        _api.fetchList('feedinglogs'),
        _api.fetchList('mortalitylogs'),
        _api.fetchList('maintenancelogs'),
        _api.fetchHarvests(),
        _api.fetchList('diseaselogs'),
        _api.fetchList('treatmentlogs'),
        _api.fetchList('feedingschedules'),
        _api.fetchList('cropcycles'),
        _api.fetchList('equipment'),
        _api.fetchList('dailylogs'),
        _api.fetchList('waterchangelogs'),
        _api.fetchList('sizemeasurements'),
      ]);
      branches = results[0].map((e) => Branch.fromJson(e)).toList();
      zones = results[1].map((e) => Zone.fromJson(e)).toList();
      ponds = results[2].map((e) => Pond.fromJson(e)).toList();
      species = results[3].map((e) => Species.fromJson(e)).toList();
      fishBatches = results[4].map((e) => FishBatch.fromJson(e)).toList();
      products = results[5].map((e) => Product.fromJson(e)).toList();
      employees = results[6].map((e) => Employee.fromJson(e)).toList();
      tasks = results[7].map((e) => Task.fromJson(e)).toList();
      customers = results[8].map((e) => Customer.fromJson(e)).toList();
      saleOrders = results[9].map((e) => SaleOrder.fromJson(e)).toList();
      purchaseOrders = results[10].map((e) => PurchaseOrder.fromJson(e)).toList();
      notifications = results[11];
      suppliers = results[12].map((e) => Supplier.fromJson(e)).toList();
      stockReceipts = results[13].map((e) => StockReceipt.fromJson(e)).toList();
      stockIssues = results[14].map((e) => StockIssue.fromJson(e)).toList();
      stockTakes = results[15].map((e) => StockTake.fromJson(e)).toList();
      paymentVouchers = results[16].map((e) => PaymentVoucher.fromJson(e)).toList();
      sensorReadings = results[17].map((e) => SensorReading.fromJson(e)).toList();
      waterStandards = results[18].map((e) => WaterStandard.fromJson(e)).toList();
      feedingLogs = results[19];
      mortalityLogs = results[20];
      maintenanceLogs = results[21];
      harvests = results[22];
      diseaseLogs = results[23].map((e) => DiseaseLog.fromJson(e)).toList();
      treatmentLogs = results[24].map((e) => TreatmentLog.fromJson(e)).toList();
      feedingSchedules = results[25].map((e) => FeedingSchedule.fromJson(e)).toList();
      cropCycles = results[26].map((e) => CropCycle.fromJson(e)).toList();
      equipmentList = results[27].map((e) => Equipment.fromJson(e)).toList();
      dailyLogs = results[28].map((e) => DailyLog.fromJson(e)).toList();
      waterChangeLogs = results[29].map((e) => WaterChangeLog.fromJson(e)).toList();
      sizeMeasurements = results[30].map((e) => SizeMeasurement.fromJson(e)).toList();
      await loadDashboard();
    } catch (e) {
      debugPrint('loadAll error: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ── Factory Reset ──
  Future<bool> factoryReset() async {
    try {
      final resp = await _api.post('/factory-reset');
      if (resp.statusCode == 200) {
        await loadAll();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('factoryReset error: $e');
      return false;
    }
  }

  // ── Reload single resource ──
  Future<void> reload(String resource) async {
    try {
      final list = await _api.fetchList(resource);
      debugPrint('[DP] reload($resource) → got ${list.length} items');
      switch (resource) {
      case 'branches': branches = list.map((e) => Branch.fromJson(e)).toList();
      case 'zones': zones = list.map((e) => Zone.fromJson(e)).toList();
      case 'ponds': ponds = list.map((e) => Pond.fromJson(e)).toList();
      case 'species': species = list.map((e) => Species.fromJson(e)).toList();
      case 'fishbatches': fishBatches = list.map((e) => FishBatch.fromJson(e)).toList();
      case 'products': products = list.map((e) => Product.fromJson(e)).toList();
      case 'employees': employees = list.map((e) => Employee.fromJson(e)).toList();
      case 'tasks': tasks = list.map((e) => Task.fromJson(e)).toList();
      case 'customers': customers = list.map((e) => Customer.fromJson(e)).toList();
      case 'saleorders': saleOrders = list.map((e) => SaleOrder.fromJson(e)).toList();
      case 'purchaseorders': purchaseOrders = list.map((e) => PurchaseOrder.fromJson(e)).toList();
      case 'notifications': notifications = list;
      case 'suppliers': suppliers = list.map((e) => Supplier.fromJson(e)).toList();
      case 'stockreceipts': stockReceipts = list.map((e) => StockReceipt.fromJson(e)).toList();
      case 'stockissues': stockIssues = list.map((e) => StockIssue.fromJson(e)).toList();
      case 'stocktakes': stockTakes = list.map((e) => StockTake.fromJson(e)).toList();
      case 'paymentvouchers': paymentVouchers = list.map((e) => PaymentVoucher.fromJson(e)).toList();
      case 'sensorreadings': sensorReadings = list.map((e) => SensorReading.fromJson(e)).toList();
      case 'waterstandards': waterStandards = list.map((e) => WaterStandard.fromJson(e)).toList();
      case 'feedinglogs': feedingLogs = list;
      case 'mortalitylogs': mortalityLogs = list;
      case 'maintenancelogs': maintenanceLogs = list;
      case 'diseaselogs': diseaseLogs = list.map((e) => DiseaseLog.fromJson(e)).toList();
      case 'treatmentlogs': treatmentLogs = list.map((e) => TreatmentLog.fromJson(e)).toList();
      case 'feedingschedules': feedingSchedules = list.map((e) => FeedingSchedule.fromJson(e)).toList();
      case 'cropcycles': cropCycles = list.map((e) => CropCycle.fromJson(e)).toList();
      case 'equipment': equipmentList = list.map((e) => Equipment.fromJson(e)).toList();
      case 'dailylogs': dailyLogs = list.map((e) => DailyLog.fromJson(e)).toList();
      case 'waterchangelogs': waterChangeLogs = list.map((e) => WaterChangeLog.fromJson(e)).toList();
      case 'sizemeasurements': sizeMeasurements = list.map((e) => SizeMeasurement.fromJson(e)).toList();
      default: debugPrint('[DP] reload: unknown resource $resource');
    }
    notifyListeners();
    } catch (e) {
      debugPrint('[DP] reload($resource) error: $e');
    }
  }

  // ── Cascade dependencies ──
  // When a resource changes on the backend, these related resources
  // are also affected and need to be reloaded.
  static const _cascadeReloads = <String, List<String>>{
    'saleorders':      ['stockissues', 'paymentvouchers', 'products', 'customers', 'fishbatches', 'ponds'],
    'purchaseorders':  ['paymentvouchers', 'stockreceipts'],
    'stockreceipts':   ['products'],
    'stockissues':     ['products', 'fishbatches', 'feedinglogs'],
    'paymentvouchers': ['customers'],
    'ponds':           ['sensorreadings', 'notifications', 'fishbatches', 'tasks'],
    'fishbatches':     ['ponds'],
    'maintenancelogs': ['ponds', 'products', 'tasks'],
    'diseaselogs':      ['treatmentlogs', 'notifications'],
    'treatmentlogs':    ['diseaselogs', 'notifications'],
    'feedingschedules': ['feedinglogs'],
    'cropcycles':       ['fishbatches'],
    'waterchangelogs':  ['ponds'],
    'sizemeasurements': ['fishbatches'],
  };

  Future<void> _reloadWithCascade(String resource) async {
    await reload(resource);
    final cascades = _cascadeReloads[resource];
    if (cascades != null) {
      // Loại bỏ cascade vòng (tránh fishbatches→ponds→fishbatches)
      final safeCascades = cascades.where((r) => r != resource).toList();
      await Future.wait(safeCascades.map((r) => reload(r)));
    }
  }

  // ── CRUD helpers ──
  Future<bool> create(String resource, Map<String, dynamic> data) async {
    debugPrint('[DP] create($resource) → calling API...');
    final result = await _api.create(resource, data);
    debugPrint('[DP] create($resource) → API result: ${result != null ? 'OK' : 'FAIL'}');
    if (result != null) {
      await _reloadWithCascade(resource);
      await loadDashboard();
      debugPrint('[DP] create($resource) → reload done, notified listeners');
      return true;
    }
    return false;
  }

  Future<bool> update(String resource, String id, Map<String, dynamic> data) async {
    debugPrint('[DP] update($resource, $id) → calling API...');
    final result = await _api.update(resource, id, data);
    debugPrint('[DP] update($resource, $id) → API result: ${result != null ? 'OK' : 'FAIL'}');
    if (result != null) {
      await _reloadWithCascade(resource);
      await loadDashboard();
      debugPrint('[DP] update($resource) → reload done, notified listeners');
      return true;
    }
    return false;
  }

  Future<bool> remove(String resource, String id) async {
    debugPrint('[DP] remove($resource, $id) → calling API...');
    final ok = await _api.remove(resource, id);
    debugPrint('[DP] remove($resource, $id) → API result: ${ok ? 'OK' : 'FAIL'}');
    if (ok) {
      await _reloadWithCascade(resource);
      await loadDashboard();
      debugPrint('[DP] remove($resource) → reload done, notified listeners');
    }
    return ok;
  }

  // ── Lookup helpers ──
  Branch? branchById(String id) => branches.where((b) => b.id == id).firstOrNull;
  Zone? zoneById(String id) => zones.where((z) => z.id == id).firstOrNull;
  Pond? pondById(String id) => ponds.where((p) => p.id == id).firstOrNull;
  Species? speciesById(String id) => species.where((s) => s.id == id).firstOrNull;
  Employee? employeeById(String id) => employees.where((e) => e.id == id).firstOrNull;
  Customer? customerById(String id) => customers.where((c) => c.id == id).firstOrNull;
  Supplier? supplierById(String id) => suppliers.where((s) => s.id == id).firstOrNull;
  Product? productById(String id) => products.where((p) => p.id == id).firstOrNull;

  List<Zone> zonesForBranch(String branchId) => zones.where((z) => z.branchId == branchId).toList();
  List<Pond> pondsForZone(String zoneId) => ponds.where((p) => p.zoneId == zoneId).toList();
  List<FishBatch> batchesForPond(String pondId) => fishBatches.where((b) => b.pondAllocations.any((a) => a['pondId'] == pondId) || b.pondId == pondId).toList();
  List<Task> tasksForPond(String pondId) => tasks.where((t) => t.pondId == pondId).toList();

  int get activePonds => ponds.where((p) => p.status == 'active').length;
  int get inactivePonds => ponds.where((p) => p.status == 'inactive').length;
  int get activeBatches => fishBatches.where((b) => b.status == 'active').length;
  int get pendingTasks => tasks.where((t) => t.status == 'pending').length;
  int get overdueTasks => tasks.where((t) => t.isOverdue).length;
  int get lowStockCount => products.where((p) => p.isLowStock).length;
  int get unreadNotifications => notifications.where((n) => n['read'] != true).length;
  double get totalDebt => customers.fold(0.0, (s, c) => s + c.debt);

  // Payment voucher stats
  double get totalReceipts => paymentVouchers.where((v) => v.isReceipt && v.status == 'confirmed').fold(0.0, (s, v) => s + v.amount);
  double get totalPayments => paymentVouchers.where((v) => v.isPayment && v.status == 'confirmed').fold(0.0, (s, v) => s + v.amount);
  double get cashBalance => totalReceipts - totalPayments;

  // Sensor readings for a pond
  List<SensorReading> readingsForPond(String pondId) =>
    sensorReadings.where((r) => r.pondId == pondId).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

  /// Trigger backend notification check (overdue tasks, low stock, high debt, disease, equipment, etc.)
  Future<void> checkNotifications() async {
    try {
      await _api.post('/notifications/check');
      await reload('notifications');
    } catch (e) {
      debugPrint('checkNotifications error: $e');
      rethrow;
    }
  }

  /// Mark a single notification as read
  Future<void> markNotificationRead(String id) async {
    try {
      final ok = await _api.markNotificationRead(id);
      if (ok) {
        final idx = notifications.indexWhere((n) => n['_id'] == id);
        if (idx >= 0) notifications[idx]['read'] = true;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('markNotificationRead error: $e');
    }
  }

  /// Mark all notifications as read
  Future<void> markAllNotificationsRead() async {
    try {
      final ok = await _api.markAllNotificationsRead();
      if (ok) {
        for (final n in notifications) { n['read'] = true; }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('markAllNotificationsRead error: $e');
    }
  }

  /// Delete a notification
  Future<void> deleteNotification(String id) async {
    try {
      final ok = await _api.remove('notifications', id);
      if (ok) {
        notifications.removeWhere((n) => n['_id'] == id);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('deleteNotification error: $e');
    }
  }

  /// Delete all read notifications
  Future<void> clearReadNotifications() async {
    try {
      final ok = await _api.clearReadNotifications();
      if (ok) {
        notifications.removeWhere((n) => n['read'] == true);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('clearReadNotifications error: $e');
    }
  }

  /// Re-notify listeners so Task.isOverdue re-computes with current time
  void refreshOverdueState() {
    notifyListeners();
  }

  /// Load audit logs for payment vouchers
  Future<List<Map<String, dynamic>>> loadAuditLogs() async {
    try {
      final resp = await _api.get('/auditlogs/paymentvouchers');
      if (resp.statusCode == 200 && resp.data is List) {
        auditLogs = List<Map<String, dynamic>>.from(resp.data as List);
        return auditLogs;
      }
    } catch (e) {
      debugPrint('loadAuditLogs error: $e');
    }
    return [];
  }

  // ── Export CSV ──
  Future<String?> exportCsv(String resource) => _api.exportCsv(resource);

  // ── Search ──
  Future<void> search(String query) async {
    searchResults = await _api.search(query);
    notifyListeners();
  }

  void clearSearch() {
    searchResults = [];
    notifyListeners();
  }

  // ── Profile ──
  Future<Map<String, dynamic>?> updateProfile(Map<String, dynamic> body) =>
      _api.updateProfile(body);

  Future<bool> changePassword(String current, String newPwd) =>
      _api.changePassword(current, newPwd);

  // ── Harvest ──
  Future<bool> createHarvest(Map<String, dynamic> body) async {
    final r = await _api.createHarvest(body);
    if (r != null) {
      await Future.wait([reload('fishbatches'), reload('ponds'), loadHarvests()]);
      await loadDashboard();
      return true;
    }
    return false;
  }

  Future<void> loadHarvests() async {
    try {
      harvests = await _api.fetchHarvests();
      notifyListeners();
    } catch (e) {
      debugPrint('loadHarvests error: $e');
    }
  }

  // ── Profit analysis ──
  Future<void> loadProfitAnalysis() async {
    try {
      profitAnalysis = await _api.fetchProfitAnalysis();
      notifyListeners();
    } catch (e) {
      debugPrint('loadProfitAnalysis error: $e');
    }
  }

  // ── Supplier debts ──
  Future<void> loadSupplierDebts() async {
    try {
      supplierDebts = await _api.fetchSupplierDebts();
      notifyListeners();
    } catch (e) {
      debugPrint('loadSupplierDebts error: $e');
    }
  }

  double get totalSupplierDebt =>
      supplierDebts.fold(0.0, (s, d) => s + ((d['debt'] as num?)?.toDouble() ?? 0));

  // ── Feeding logs ──
  Future<bool> createFeedingLog(Map<String, dynamic> body) async {
    final r = await _api.createFeedingLog(body);
    if (r != null) {
      await Future.wait([loadFeedingLogs(), reload('fishbatches'), reload('products')]);
      return true;
    }
    return false;
  }

  Future<void> loadFeedingLogs() async {
    try {
      feedingLogs = await _api.fetchFeedingLogs();
      notifyListeners();
    } catch (e) {
      debugPrint('loadFeedingLogs error: $e');
    }
  }

  // ── Mortality logs ──
  Future<bool> createMortalityLog(Map<String, dynamic> body) async {
    final r = await _api.createMortalityLog(body);
    if (r != null) {
      await Future.wait([loadMortalityLogs(), reload('fishbatches')]);
      return true;
    }
    return false;
  }

  Future<void> loadMortalityLogs() async {
    try {
      mortalityLogs = await _api.fetchMortalityLogs();
      notifyListeners();
    } catch (e) {
      debugPrint('loadMortalityLogs error: $e');
    }
  }

  // ── Maintenance logs ──
  Future<Map<String, dynamic>?> startMaintenance(Map<String, dynamic> body) async {
    final resp = await _api.post('/maintenance/start', body: body);
    if (resp.statusCode == 201 && resp.data != null) {
      await Future.wait([reload('maintenancelogs'), reload('ponds'), reload('tasks'), reload('products'), reload('stockissues')]);
      return resp.data as Map<String, dynamic>;
    }
    return null;
  }

  Future<bool> updateMaintenanceItem(String logId, int itemIndex, Map<String, dynamic> body) async {
    final resp = await _api.put('/maintenance/$logId/item/$itemIndex', body: body);
    if (resp.statusCode == 200) {
      await reload('maintenancelogs');
      return true;
    }
    return false;
  }

  Future<bool> finishMaintenance(String logId, Map<String, dynamic> body) async {
    final resp = await _api.put('/maintenance/$logId/finish', body: body);
    if (resp.statusCode == 200) {
      await Future.wait([reload('maintenancelogs'), reload('ponds'), reload('tasks')]);
      return true;
    }
    return false;
  }

  List<Map<String, dynamic>> maintenanceLogsForPond(String pondId) =>
    maintenanceLogs.where((l) => l['pondId'] == pondId).toList()
      ..sort((a, b) => (b['createdAt'] ?? '').compareTo(a['createdAt'] ?? ''));

  Map<String, dynamic>? activeMaintenanceForPond(String pondId) {
    final list = maintenanceLogs.where((l) => l['pondId'] == pondId && l['status'] == 'in_progress').toList();
    return list.isNotEmpty ? list.first : null;
  }
}
