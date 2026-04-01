require('dotenv').config();
const express = require('express');
const cors = require('cors');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const app = express();
app.use(cors());
app.use(express.json());

// ── File-based persistence ──
const DB_FILE = path.join(__dirname, 'data.json');

function saveDb() {
  try {
    const safeDb = {};
    for (const key of Object.keys(db)) {
      safeDb[key] = db[key];
    }
    fs.writeFileSync(DB_FILE, JSON.stringify(safeDb, null, 2), 'utf8');
  } catch (e) { console.error('DB save error:', e.message); }
}

function loadDb() {
  try {
    if (fs.existsSync(DB_FILE)) {
      const raw = fs.readFileSync(DB_FILE, 'utf8');
      return JSON.parse(raw);
    }
  } catch (e) { console.error('DB load error:', e.message); }
  return null;
}

// Auto-save every 30 seconds
setInterval(saveDb, 30000);

// ── Data store (loaded from file or seed) ──
const db = {
  employees: [
    { _id: '1', name: 'Nguyễn Văn An', email: 'admin@aqua.vn', password: '$2a$10$ADXQvuXfHsVYvWR1uo2F.uHPmu1pJ8sp62R33AymSZxIFygkScd4G', role: 'owner', phone: '0901234567', branchId: '1', storeId: '1', shift: 'Sáng', hasAccount: true, permissions: [], storeName: 'Chi nhánh Cần Thơ', createdAt: '2026-01-01T00:00:00.000Z' },
    { _id: '2', name: 'Trần Thị Bình', email: 'binh@aqua.vn', password: '$2a$10$ADXQvuXfHsVYvWR1uo2F.uHPmu1pJ8sp62R33AymSZxIFygkScd4G', role: 'technician', phone: '0912345678', branchId: '1', storeId: '1', shift: 'Chiều', hasAccount: false, permissions: [], createdAt: '2026-01-15T00:00:00.000Z' },
    { _id: '3', name: 'Lê Văn Cường', email: 'cuong@aqua.vn', password: '$2a$10$ADXQvuXfHsVYvWR1uo2F.uHPmu1pJ8sp62R33AymSZxIFygkScd4G', role: 'worker', phone: '0923456789', branchId: '1', storeId: '1', shift: 'Sáng', hasAccount: false, permissions: [], createdAt: '2026-02-01T00:00:00.000Z' },
  ],
  branches: [
    { _id: '1', name: 'Chi nhánh Cần Thơ', address: 'KCN Trà Nóc, Cần Thơ', contact: '0901234567', manager: 'Nguyễn Văn An', storeId: '1', createdAt: '2026-01-01T00:00:00.000Z' },
    { _id: '2', name: 'Chi nhánh Vĩnh Long', address: 'Huyện Long Hồ, Vĩnh Long', contact: '0934567890', manager: 'Phạm Thị D', storeId: '1', createdAt: '2026-02-01T00:00:00.000Z' },
  ],
  zones: [
    { _id: '1', name: 'Khu A - Nuôi thâm canh', branchId: '1', storeId: '1', type: 'farming', createdAt: '2026-01-01T00:00:00.000Z' },
    { _id: '2', name: 'Khu B - Nuôi bán thâm canh', branchId: '1', storeId: '1', type: 'farming', createdAt: '2026-01-01T00:00:00.000Z' },
    { _id: '3', name: 'Khu C - Xử lý nước', branchId: '1', storeId: '1', type: 'treatment', createdAt: '2026-01-01T00:00:00.000Z' },
    { _id: '4', name: 'Khu D - Hậu cần', branchId: '1', storeId: '1', type: 'logistics', createdAt: '2026-01-01T00:00:00.000Z' },
    { _id: '5', name: 'Khu E - Nuôi', branchId: '2', storeId: '1', type: 'farming', createdAt: '2026-02-01T00:00:00.000Z' },
  ],
  ponds: [
    { _id: '1', code: 'A1', zoneId: '1', storeId: '1', area: 500, volume: 1000, depth: 2.0, type: 'earth', status: 'active', currentPh: 7.2, currentDo: 6.5, currentTemp: 28, currentNh3: 0.02, currentAlkalinity: 120, measuredBy: '2', createdAt: '2026-01-01T00:00:00.000Z', updatedAt: '2026-06-01T00:00:00.000Z' },
    { _id: '2', code: 'A2', zoneId: '1', storeId: '1', area: 300, volume: 600, depth: 2.0, type: 'hdpe', status: 'active', currentPh: 7.0, currentDo: 5.8, currentTemp: 27, currentNh3: 0.01, currentAlkalinity: 110, measuredBy: '2', createdAt: '2026-01-01T00:00:00.000Z', updatedAt: '2026-06-01T00:00:00.000Z' },
    { _id: '3', code: 'B1', zoneId: '2', storeId: '1', area: 800, volume: 1600, depth: 2.0, type: 'earth', status: 'inactive', currentPh: null, currentDo: null, currentTemp: null, currentNh3: null, currentAlkalinity: null, measuredBy: '', createdAt: '2026-01-01T00:00:00.000Z', updatedAt: null },
    { _id: '4', code: 'B2', zoneId: '2', storeId: '1', area: 200, volume: 400, depth: 2.0, type: 'cage', status: 'maintenance', currentPh: 6.8, currentDo: 7.1, currentTemp: 29, currentNh3: 0.005, currentAlkalinity: 95, measuredBy: '2', createdAt: '2026-01-01T00:00:00.000Z', updatedAt: '2026-05-15T00:00:00.000Z' },
    { _id: '5', code: 'C1', zoneId: '3', storeId: '1', area: 100, volume: 200, depth: 2.0, type: 'hdpe', status: 'active', currentPh: 7.5, currentDo: 6.0, currentTemp: 26, currentNh3: 0.03, currentAlkalinity: 130, measuredBy: '3', createdAt: '2026-01-15T00:00:00.000Z', updatedAt: '2026-06-01T00:00:00.000Z' },
    { _id: '6', code: 'E1', zoneId: '5', storeId: '1', area: 600, volume: 1200, depth: 2.0, type: 'earth', status: 'active', currentPh: 7.1, currentDo: 6.2, currentTemp: 28, currentNh3: 0.015, currentAlkalinity: 105, measuredBy: '3', createdAt: '2026-02-01T00:00:00.000Z', updatedAt: '2026-06-01T00:00:00.000Z' },
  ],
  species: [
    { _id: '1', name: 'Cá tra', description: 'Pangasius', storeId: '1', requiredTemp: 28, minTemp: 22, maxTemp: 32, requiredPh: 7.0, requiredDo: 3.5, maxNh3: 0.1, feedRatio: 1.5, harvestableWeight: 800, growthDays: 180, densityPerM2: 8, createdAt: '2026-01-01T00:00:00.000Z', updatedAt: '2026-01-01T00:00:00.000Z' },
    { _id: '2', name: 'Cá rô phi', description: 'Tilapia', storeId: '1', requiredTemp: 26, minTemp: 20, maxTemp: 35, requiredPh: 7.2, requiredDo: 4.0, maxNh3: 0.08, feedRatio: 1.3, harvestableWeight: 500, growthDays: 150, densityPerM2: 5, createdAt: '2026-01-01T00:00:00.000Z', updatedAt: '2026-01-01T00:00:00.000Z' },
    { _id: '3', name: 'Tôm sú', description: 'Black Tiger Shrimp', storeId: '1', requiredTemp: 29, minTemp: 25, maxTemp: 33, requiredPh: 7.8, requiredDo: 5.0, maxNh3: 0.05, feedRatio: 1.8, harvestableWeight: 30, growthDays: 120, densityPerM2: 20, createdAt: '2026-01-01T00:00:00.000Z', updatedAt: '2026-01-01T00:00:00.000Z' },
    { _id: '4', name: 'Cá lóc', description: 'Snakehead', storeId: '1', requiredTemp: 27, minTemp: 22, maxTemp: 34, requiredPh: 7.0, requiredDo: 3.0, maxNh3: 0.15, feedRatio: 1.6, harvestableWeight: 600, growthDays: 210, densityPerM2: 3, createdAt: '2026-01-01T00:00:00.000Z', updatedAt: '2026-01-01T00:00:00.000Z' },
  ],
  fishbatches: [
    { _id: '1', pondId: '1', speciesId: '1', storeId: '1', stockingDate: '2026-02-15T00:00:00.000Z', initialQuantity: 5000, initialSize: 5, initialWeight: 3, currentQuantity: 4800, currentSize: 25, currentWeight: 350, mortalityQuantity: 200, feedConsumed: 2100, expectedHarvestDate: '2026-08-15T00:00:00.000Z', status: 'active', source: 'Trại giống Cần Thơ', note: 'Lô cá tra đầu tiên', createdBy: '1', inspectedBy: '2', createdAt: '2026-02-15T00:00:00.000Z', updatedAt: '2026-06-01T00:00:00.000Z' },
    { _id: '2', pondId: '2', speciesId: '2', storeId: '1', stockingDate: '2026-03-01T00:00:00.000Z', initialQuantity: 3000, initialSize: 4, initialWeight: 2, currentQuantity: 2950, currentSize: 18, currentWeight: 280, mortalityQuantity: 50, feedConsumed: 980, expectedHarvestDate: '2026-09-01T00:00:00.000Z', status: 'active', source: 'Trại giống Vĩnh Long', note: '', createdBy: '1', inspectedBy: '2', createdAt: '2026-03-01T00:00:00.000Z', updatedAt: '2026-06-01T00:00:00.000Z' },
    { _id: '3', pondId: '5', speciesId: '3', storeId: '1', stockingDate: '2026-03-10T00:00:00.000Z', initialQuantity: 10000, initialSize: 2, initialWeight: 0.5, currentQuantity: 9800, currentSize: 10, currentWeight: 15, mortalityQuantity: 200, feedConsumed: 250, expectedHarvestDate: '2026-07-10T00:00:00.000Z', status: 'active', source: 'Trại giống Bạc Liêu', note: 'Tôm sú lứa 1', createdBy: '2', inspectedBy: '3', createdAt: '2026-03-10T00:00:00.000Z', updatedAt: '2026-06-01T00:00:00.000Z' },
  ],
  products: [
    { _id: '1', sku: 'TA-001', name: 'Thức ăn cá tra 30%', category: 'feed', unit: 'kg', price: 15000, stock: 500, minStock: 100, storeId: '1', createdAt: '2026-01-01T00:00:00.000Z' },
    { _id: '2', sku: 'TA-002', name: 'Thức ăn tôm sú', category: 'feed', unit: 'kg', price: 35000, stock: 200, minStock: 50, storeId: '1', createdAt: '2026-01-01T00:00:00.000Z' },
    { _id: '3', sku: 'HC-001', name: 'Vi sinh xử lý nước', category: 'chemical', unit: 'lít', price: 120000, stock: 30, minStock: 10, storeId: '1', createdAt: '2026-01-01T00:00:00.000Z' },
    { _id: '4', sku: 'TH-001', name: 'Thuốc trị bệnh đốm trắng', category: 'medicine', unit: 'chai', price: 250000, stock: 15, minStock: 5, storeId: '1', createdAt: '2026-01-01T00:00:00.000Z' },
    { _id: '5', sku: 'GI-001', name: 'Giống cá tra', category: 'seed', unit: 'con', price: 500, stock: 0, minStock: 0, storeId: '1', createdAt: '2026-01-01T00:00:00.000Z' },
    { _id: '6', sku: 'HC-002', name: 'Oxy viên', category: 'chemical', unit: 'kg', price: 80000, stock: 50, minStock: 20, storeId: '1', createdAt: '2026-01-01T00:00:00.000Z' },
  ],
  purchaseorders: [
    { _id: '1', code: 'PO-001', date: '2026-03-01T00:00:00.000Z', supplierId: '1', supplier: 'Cty TNHH Thức ăn ABC', branchId: '1', storeId: '1', items: [{productId: '1', productName: 'Thức ăn cá tra 30%', qty: 200, unitPrice: 15000, unit: 'kg'}, {productId: '3', productName: 'Vi sinh xử lý nước', qty: 10, unitPrice: 120000, unit: 'lít'}], total: 4200000, status: 'completed', note: '', createdBy: '1', createdAt: '2026-03-01T00:00:00.000Z' },
    { _id: '2', code: 'PO-002', date: '2026-03-15T00:00:00.000Z', supplierId: '2', supplier: 'Trại giống Cần Thơ', branchId: '1', storeId: '1', items: [{productId: '5', productName: 'Giống cá tra', qty: 5000, unitPrice: 500, unit: 'con'}], total: 2500000, status: 'completed', note: '', createdBy: '2', createdAt: '2026-03-15T00:00:00.000Z' },
  ],
  stocktransactions: [
    { _id: '1', productId: '1', type: 'in', qty: 200, date: '2026-03-01T00:00:00.000Z', reason: 'Nhập hàng PO-001', userId: '1', storeId: '1', createdAt: '2026-03-01T00:00:00.000Z' },
    { _id: '2', productId: '1', type: 'out', qty: 50, date: '2026-03-10T00:00:00.000Z', reason: 'Cho ăn ao A1', userId: '3', storeId: '1', createdAt: '2026-03-10T00:00:00.000Z' },
  ],
  sizemeasurements: [
    { _id: '1', fishBatchId: '1', pondId: '1', storeId: '1', date: '2026-03-10T00:00:00.000Z', avgWeight: 50, avgLength: 12, sampleCount: 30, remainingQty: 4850, measuredBy: 'Trần Thị Bình', note: 'Đo định kỳ tuần 2', createdAt: '2026-03-10T00:00:00.000Z' },
    { _id: '2', fishBatchId: '1', pondId: '1', storeId: '1', date: '2026-03-20T00:00:00.000Z', avgWeight: 85, avgLength: 15, sampleCount: 25, remainingQty: 4800, measuredBy: 'Trần Thị Bình', note: 'Đo định kỳ tuần 4', createdAt: '2026-03-20T00:00:00.000Z' },
  ],
  transfers: [
    { _id: '1', fromPondId: '1', toPondId: '3', fishBatchId: '1', storeId: '1', date: '2026-03-18T00:00:00.000Z', qty: 200, weight: 10, reason: 'San thưa mật độ', createdAt: '2026-03-18T00:00:00.000Z' },
  ],
  othercosts: [
    { _id: '1', pondId: '1', fishBatchId: '1', branchId: '1', storeId: '1', date: '2026-03-05T00:00:00.000Z', type: 'maintenance', amount: 500000, note: 'Sửa cống xả ao A1', createdAt: '2026-03-05T00:00:00.000Z' },
    { _id: '2', branchId: '1', storeId: '1', date: '2026-03-15T00:00:00.000Z', type: 'salary', amount: 15000000, note: 'Lương tháng 3/2026', createdAt: '2026-03-15T00:00:00.000Z' },
  ],
  tasks: [
    { _id: '1', assignedTo: '3', pondId: '1', storeId: '1', type: 'feeding', title: 'Cho ăn ao A1', dueDate: '2026-03-21T08:00:00.000Z', status: 'pending', note: '50kg thức ăn', createdAt: '2026-03-20T00:00:00.000Z' },
    { _id: '2', assignedTo: '2', pondId: '2', storeId: '1', type: 'water_check', title: 'Đo thông số nước ao A2', dueDate: '2026-03-21T10:00:00.000Z', status: 'pending', note: 'Đo pH, DO, NH3', createdAt: '2026-03-20T00:00:00.000Z' },
    { _id: '3', assignedTo: '3', pondId: '1', storeId: '1', type: 'water_change', title: 'Thay nước ao A1', dueDate: '2026-03-20T14:00:00.000Z', status: 'done', note: 'Thay 30% nước', createdAt: '2026-03-19T00:00:00.000Z' },
    { _id: '4', assignedTo: '2', pondId: '5', storeId: '1', type: 'feeding', title: 'Cho ăn ao C1', dueDate: '2026-03-22T07:00:00.000Z', status: 'pending', note: '20kg thức ăn tôm', createdAt: '2026-03-21T00:00:00.000Z' },
  ],
  attendance: [
    { _id: '1', employeeId: '3', storeId: '1', date: '2026-03-21', shift: 'Sáng', timeIn: '06:00', timeOut: '12:00', createdAt: '2026-03-21T06:00:00.000Z' },
  ],
  customers: [
    { _id: '1', name: 'Chợ đầu mối Bình Điền', type: 'wholesale', address: 'Q.8, TP.HCM', contact: '0987654321', debt: 5000000, storeId: '1', createdAt: '2026-01-01T00:00:00.000Z' },
    { _id: '2', name: 'Nhà hàng Hải Sản Biển Đông', type: 'retail', address: 'Ninh Kiều, Cần Thơ', contact: '0911223344', debt: 0, storeId: '1', createdAt: '2026-02-01T00:00:00.000Z' },
    { _id: '3', name: 'Đại lý Minh Phát', type: 'wholesale', address: 'Long Xuyên, An Giang', contact: '0966778899', debt: 12000000, storeId: '1', createdAt: '2026-02-15T00:00:00.000Z' },
  ],
  saleorders: [
    { _id: '1', customerId: '1', date: '2026-03-18T00:00:00.000Z', pondId: '1', fishBatchId: '1', storeId: '1', items: [{product: 'Cá tra', qty: 500, price: 28000, shippingFee: 500000}], totalAmount: 14500000, status: 'completed', createdAt: '2026-03-18T00:00:00.000Z' },
    { _id: '2', customerId: '3', date: '2026-03-20T00:00:00.000Z', pondId: '2', fishBatchId: '2', storeId: '1', items: [{product: 'Cá rô phi', qty: 200, price: 35000, shippingFee: 300000}], totalAmount: 7300000, status: 'pending', createdAt: '2026-03-20T00:00:00.000Z' },
  ],
  payments: [
    { _id: '1', orderId: '1', customerId: '1', storeId: '1', date: '2026-03-18T00:00:00.000Z', amount: 9500000, method: 'transfer', createdAt: '2026-03-18T00:00:00.000Z' },
  ],
  notifications: [
    { _id: '1', title: 'pH cao bất thường', message: 'Ao A1 pH = 8.5, vượt ngưỡng 8.0', type: 'warning', priority: 'high', read: false, pondId: '1', storeId: '1', createdAt: '2026-03-21T02:00:00.000Z' },
    { _id: '2', title: 'Tồn kho thấp', message: 'Vi sinh xử lý nước còn 30 lít (tối thiểu 10)', type: 'warning', priority: 'medium', read: false, productId: '3', storeId: '1', createdAt: '2026-03-20T08:00:00.000Z' },
  ],
  reports: [],
  suppliers: [
    { _id: '1', name: 'Cty TNHH Thức ăn ABC', phone: '0901234567', email: 'abc@food.vn', address: 'Q.Bình Tân, TP.HCM', taxCode: '0301234567', note: 'NCC thức ăn chính', storeId: '1', createdAt: '2026-01-01T00:00:00.000Z' },
    { _id: '2', name: 'Trại giống Cần Thơ', phone: '0912345678', email: 'giong@cantho.vn', address: 'Ninh Kiều, Cần Thơ', taxCode: '1801234567', note: 'Giống cá, tôm', storeId: '1', createdAt: '2026-01-15T00:00:00.000Z' },
    { _id: '3', name: 'Công ty Hoá chất Xanh', phone: '0923456789', email: 'xanh@chem.vn', address: 'Long An', taxCode: '0401234567', note: 'Vi sinh, hoá chất', storeId: '1', createdAt: '2026-02-01T00:00:00.000Z' },
  ],
  stockreceipts: [
    { _id: '1', code: 'NK-001', date: '2026-03-01T00:00:00.000Z', type: 'purchase', purchaseOrderId: '1', supplierId: '1', branchId: '1', storeId: '1', items: [{productId: '1', productName: 'Thức ăn cá tra 30%', qty: 200, receivedQty: 200, unitPrice: 15000, unit: 'kg'}, {productId: '3', productName: 'Vi sinh xử lý nước', qty: 10, receivedQty: 10, unitPrice: 120000, unit: 'lít'}], totalAmount: 4200000, status: 'approved', note: 'Nhập đủ theo PO-001', createdBy: '1', approvedBy: '1', createdAt: '2026-03-01T00:00:00.000Z' },
  ],
  stockissues: [
    { _id: '1', code: 'XK-001', date: '2026-03-10T00:00:00.000Z', type: 'usage', saleOrderId: '', pondId: '1', branchId: '1', storeId: '1', items: [{productId: '1', productName: 'Thức ăn cá tra 30%', qty: 50, unitPrice: 15000, unit: 'kg'}], totalAmount: 750000, status: 'approved', note: 'Cho ăn ao A1', createdBy: '1', issuedTo: '3', approvedBy: '1', createdAt: '2026-03-10T00:00:00.000Z' },
  ],
  stocktakes: [],
  paymentvouchers: [
    { _id: '1', code: 'PT-001', type: 'receipt', category: 'ban_hang', amount: 9500000, contactName: 'Cty CP Thủy sản Sài Gòn', contactId: '1', contactType: 'customer', description: 'Thu tiền đơn hàng #1', date: '2026-03-18T00:00:00.000Z', paymentMethod: 'transfer', status: 'confirmed', referenceId: '1', referenceType: 'sale_order', note: '', createdBy: '1', approvedBy: '1', storeId: '1', createdAt: '2026-03-18T00:00:00.000Z' },
    { _id: '2', code: 'PC-001', type: 'payment', category: 'thuc_an', amount: 4200000, contactName: 'Cty TNHH Thức ăn ABC', contactId: '1', contactType: 'supplier', description: 'Thanh toán thức ăn cá tra', date: '2026-03-15T00:00:00.000Z', paymentMethod: 'transfer', status: 'confirmed', referenceId: '1', referenceType: 'purchase_order', note: 'Thanh toán đợt 1', createdBy: '1', approvedBy: '1', storeId: '1', createdAt: '2026-03-15T00:00:00.000Z' },
    { _id: '3', code: 'PC-002', type: 'payment', category: 'luong', amount: 15000000, contactName: 'Nguyễn Văn An', contactId: '1', contactType: 'employee', description: 'Lương tháng 3/2026', date: '2026-03-30T00:00:00.000Z', paymentMethod: 'transfer', status: 'confirmed', referenceId: '', referenceType: '', note: '', createdBy: '1', approvedBy: '1', storeId: '1', createdAt: '2026-03-30T00:00:00.000Z' },
    { _id: '4', code: 'PT-002', type: 'receipt', category: 'thu_no', amount: 5000000, contactName: 'Đại lý Minh Phát', contactId: '3', contactType: 'customer', description: 'Thu công nợ tháng 2', date: '2026-03-25T00:00:00.000Z', paymentMethod: 'cash', status: 'confirmed', referenceId: '', referenceType: '', note: 'Thu trực tiếp', createdBy: '1', approvedBy: '1', storeId: '1', createdAt: '2026-03-25T00:00:00.000Z' },
    { _id: '5', code: 'PC-003', type: 'payment', category: 'dien_nuoc', amount: 3500000, contactName: 'Điện lực Cần Thơ', contactId: '', contactType: '', description: 'Tiền điện tháng 3', date: '2026-03-28T00:00:00.000Z', paymentMethod: 'transfer', status: 'draft', referenceId: '', referenceType: '', note: '', createdBy: '1', approvedBy: '', storeId: '1', createdAt: '2026-03-28T00:00:00.000Z' },
  ],
  feedinglogs: [],
  mortalitylogs: [],
  harvests: [],
  maintenancelogs: [],
  sensorreadings: [],
  auditlogs: [],
  waterstandards: [
    { _id: 'ws1', name: 'pH', paramKey: 'ph', unit: '', safeMin: 6.5, safeMax: 9.0, optimalMin: 7.0, optimalMax: 8.5, isActive: true, note: 'Khoảng pH phù hợp cho nuôi trồng thủy sản', storeId: '1', createdAt: '2026-01-01T00:00:00.000Z' },
    { _id: 'ws2', name: 'Oxy hòa tan (DO)', paramKey: 'do', unit: 'mg/L', safeMin: 3.0, safeMax: 20.0, optimalMin: 5.0, optimalMax: 12.0, isActive: true, note: 'Mức DO tối thiểu cho cá khỏe mạnh', storeId: '1', createdAt: '2026-01-01T00:00:00.000Z' },
    { _id: 'ws3', name: 'Nhiệt độ', paramKey: 'temp', unit: '°C', safeMin: 20.0, safeMax: 35.0, optimalMin: 25.0, optimalMax: 32.0, isActive: true, note: 'Nhiệt độ nước thích hợp', storeId: '1', createdAt: '2026-01-01T00:00:00.000Z' },
    { _id: 'ws4', name: 'Amoniac (NH₃)', paramKey: 'nh3', unit: 'mg/L', safeMin: 0.0, safeMax: 0.5, optimalMin: 0.0, optimalMax: 0.1, isActive: true, note: 'NH₃ > 0.5 gây độc cho cá', storeId: '1', createdAt: '2026-01-01T00:00:00.000Z' },
    { _id: 'ws5', name: 'Độ kiềm', paramKey: 'alkalinity', unit: 'mg/L', safeMin: 60.0, safeMax: 200.0, optimalMin: 80.0, optimalMax: 150.0, isActive: true, note: 'Duy trì đệm pH ổn định', storeId: '1', createdAt: '2026-01-01T00:00:00.000Z' },
    { _id: 'ws6', name: 'Nitrit (NO₂)', paramKey: 'no2', unit: 'mg/L', safeMin: 0.0, safeMax: 1.0, optimalMin: 0.0, optimalMax: 0.3, isActive: true, note: 'NO₂ cao gây bệnh nâu mang', storeId: '1', createdAt: '2026-01-01T00:00:00.000Z' },
    { _id: 'ws7', name: 'Độ mặn', paramKey: 'salinity', unit: 'ppt', safeMin: 0.0, safeMax: 35.0, optimalMin: 5.0, optimalMax: 25.0, isActive: false, note: 'Áp dụng cho nuôi mặn/lợ', storeId: '1', createdAt: '2026-01-01T00:00:00.000Z' },
  ],
  diseaselogs: [],
  treatmentlogs: [],
  feedingschedules: [],
  cropcycles: [],
  equipment: [],
  dailylogs: [],
  waterchangelogs: [],
  sysadmins: [],
  licenses: [],
};

function genId() { return crypto.randomUUID(); }

// ── Auth routes ──
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

const JWT_SECRET = process.env.JWT_SECRET || 'aqua_secret_2026_change_in_production';

// ── JWT Auth Middleware ──
function authMiddleware(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ message: 'Chưa đăng nhập' });
  }
  try {
    const token = authHeader.split(' ')[1];
    const decoded = jwt.verify(token, JWT_SECRET);
    const user = db.employees.find(u => u._id === decoded.id);
    if (!user) return res.status(401).json({ message: 'Tài khoản không tồn tại' });
    req.user = { id: user._id, role: decoded.role, storeId: user.storeId || '' };
    next();
  } catch (err) {
    return res.status(401).json({ message: 'Token không hợp lệ hoặc đã hết hạn' });
  }
}

app.post('/api/auth/register', async (req, res) => {
  const { storeName, email, phone, address, password } = req.body;
  if (!storeName || !password) return res.status(400).json({ message: 'Vui lòng nhập đầy đủ thông tin' });
  if (!email && !phone) return res.status(400).json({ message: 'Vui lòng nhập email hoặc số điện thoại' });
  if (email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return res.status(400).json({ message: 'Email không hợp lệ' });
  if (phone && !/^(0|\+84)[0-9]{9,10}$/.test(phone)) return res.status(400).json({ message: 'Số điện thoại không hợp lệ' });
  if (password.length < 6) return res.status(400).json({ message: 'Mật khẩu phải có ít nhất 6 ký tự' });
  // Check uniqueness across ALL employees (not just those with hasAccount)
  if (email && db.employees.find(u => u.email === email && u.email !== '')) return res.status(409).json({ message: 'Email đã được đăng ký' });
  if (phone && db.employees.find(u => u.phone === phone && u.phone !== '')) return res.status(409).json({ message: 'Số điện thoại đã được đăng ký' });
  const hashed = await bcrypt.hash(password, 10);

  // Auto-create a store (branch) for the new owner
  const storeId = genId();
  const store = {
    _id: storeId,
    name: storeName,
    address: address || '',
    contact: phone || email || '',
    manager: storeName,
    createdAt: new Date().toISOString(),
  };
  db.branches.push(store);

  const user = {
    _id: genId(),
    name: storeName,
    storeName,
    email: email || '',
    phone: phone || '',
    address: address || '',
    password: hashed,
    role: 'owner',
    storeId,
    hasAccount: true,
    permissions: [],
    createdAt: new Date().toISOString(),
  };
  db.employees.push(user);

  const token = jwt.sign({ id: user._id, role: user.role }, JWT_SECRET, { expiresIn: '7d' });
  res.status(201).json({ id: user._id, email: user.email, displayName: user.name, storeName: user.storeName, phone: user.phone, address: user.address, storeId, token, role: 'owner', permissions: [] });
});

app.post('/api/auth/login', async (req, res) => {
  const { email, password } = req.body;
  if (!email || !password) return res.status(400).json({ message: 'Vui lòng nhập email/SĐT và mật khẩu' });
  const user = db.employees.find(u => (u.email === email || u.phone === email) && u.hasAccount !== false);
  if (!user) return res.status(404).json({ message: 'Tài khoản không tồn tại' });
  if (!user.password) return res.status(401).json({ message: 'Tài khoản chưa được thiết lập mật khẩu' });
  const valid = await bcrypt.compare(password, user.password);
  if (!valid) return res.status(401).json({ message: 'Mật khẩu không đúng' });
  const token = jwt.sign({ id: user._id, role: user.role }, JWT_SECRET, { expiresIn: '7d' });
  res.json({ id: user._id, email: user.email, displayName: user.name, storeName: user.storeName, phone: user.phone, address: user.address, storeId: user.storeId || '', token, role: user.role || 'owner', permissions: user.permissions || [] });
});

app.post('/api/auth/forgot-password', async (req, res) => {
  const { email } = req.body;
  if (!email) return res.status(400).json({ message: 'Vui lòng nhập email hoặc số điện thoại' });
  const user = db.employees.find(u => u.email === email || u.phone === email);
  if (!user) return res.status(404).json({ message: 'Không tìm thấy tài khoản với thông tin này' });
  const code = String(Math.floor(100000 + Math.random() * 900000));
  user.resetCode = code;
  user.resetCodeExpiry = Date.now() + 10 * 60 * 1000;
  saveDb();
  // In production, send code via email/SMS instead of logging
  if (process.env.NODE_ENV !== 'production') {
    console.log(`[DEV] Reset code for ${email}: ${code}`);
  }
  res.json({ message: 'Mã xác nhận đã được gửi' });
});

app.post('/api/auth/reset-password', async (req, res) => {
  const { email, code, newPassword } = req.body;
  if (!email || !code || !newPassword) return res.status(400).json({ message: 'Thiếu thông tin' });
  if (newPassword.length < 6) return res.status(400).json({ message: 'Mật khẩu phải có ít nhất 6 ký tự' });
  const user = db.employees.find(u => u.email === email || u.phone === email);
  if (!user) return res.status(404).json({ message: 'Không tìm thấy tài khoản' });
  if (user.resetCode !== code || !user.resetCodeExpiry || Date.now() > user.resetCodeExpiry) {
    return res.status(400).json({ message: 'Mã xác nhận không đúng hoặc đã hết hạn' });
  }
  user.password = await bcrypt.hash(newPassword, 10);
  delete user.resetCode;
  delete user.resetCodeExpiry;
  saveDb();
  res.json({ message: 'Đổi mật khẩu thành công' });
});

// ── Store User Account Management ──
app.post('/api/store-users', authMiddleware, async (req, res) => {
  const { employeeId, email, phone, password, role, permissions } = req.body;
  if (!employeeId || !password) return res.status(400).json({ message: 'Thiếu thông tin bắt buộc' });
  if (!email && !phone) return res.status(400).json({ message: 'Vui lòng nhập email hoặc số điện thoại' });
  if (password.length < 6) return res.status(400).json({ message: 'Mật khẩu phải có ít nhất 6 ký tự' });
  if (email && db.employees.find(u => u.email === email && u.email !== '' && u._id !== employeeId && u.hasAccount)) {
    return res.status(409).json({ message: 'Email đã được sử dụng cho tài khoản khác' });
  }
  if (phone && db.employees.find(u => u.phone === phone && u.phone !== '' && u._id !== employeeId && u.hasAccount)) {
    return res.status(409).json({ message: 'Số điện thoại đã được sử dụng cho tài khoản khác' });
  }
  const sid = req.user.storeId;
  const emp = db.employees.find(e => e._id === employeeId && e.storeId === sid);
  if (!emp) return res.status(404).json({ message: 'Không tìm thấy nhân viên' });
  const hashed = await bcrypt.hash(password, 10);
  emp.hasAccount = true;
  emp.password = hashed;
  emp.role = role || emp.role || 'worker';
  emp.permissions = permissions || [];
  emp.storeId = sid;
  if (email) emp.email = email;
  if (phone) emp.phone = phone;
  saveDb();
  res.status(201).json({ message: 'Tạo tài khoản thành công', employee: { _id: emp._id, name: emp.name, email: emp.email, phone: emp.phone, role: emp.role, hasAccount: emp.hasAccount, permissions: emp.permissions, branchId: emp.branchId, shift: emp.shift, createdAt: emp.createdAt } });
});

app.put('/api/store-users/:id/permissions', authMiddleware, (req, res) => {
  const { role, permissions } = req.body;
  const sid = req.user.storeId;
  const emp = db.employees.find(e => e._id === req.params.id && e.storeId === sid);
  if (!emp) return res.status(404).json({ message: 'Không tìm thấy nhân viên' });
  if (!emp.hasAccount) return res.status(400).json({ message: 'Nhân viên chưa có tài khoản' });
  if (role) emp.role = role;
  if (permissions) emp.permissions = permissions;
  saveDb();
  res.json({ message: 'Cập nhật quyền thành công', employee: { _id: emp._id, name: emp.name, email: emp.email, phone: emp.phone, role: emp.role, hasAccount: emp.hasAccount, permissions: emp.permissions, branchId: emp.branchId, shift: emp.shift, createdAt: emp.createdAt } });
});

app.put('/api/store-users/:id/reset-password', authMiddleware, async (req, res) => {
  const { newPassword } = req.body;
  if (!newPassword || newPassword.length < 6) return res.status(400).json({ message: 'Mật khẩu phải có ít nhất 6 ký tự' });
  const sid = req.user.storeId;
  const emp = db.employees.find(e => e._id === req.params.id && e.storeId === sid);
  if (!emp) return res.status(404).json({ message: 'Không tìm thấy nhân viên' });
  if (!emp.hasAccount) return res.status(400).json({ message: 'Nhân viên chưa có tài khoản' });
  emp.password = await bcrypt.hash(newPassword, 10);
  saveDb();
  res.json({ message: 'Đổi mật khẩu thành công' });
});

app.delete('/api/store-users/:id', authMiddleware, (req, res) => {
  const sid = req.user.storeId;
  const emp = db.employees.find(e => e._id === req.params.id && e.storeId === sid);
  if (!emp) return res.status(404).json({ message: 'Không tìm thấy nhân viên' });
  emp.hasAccount = false;
  delete emp.password;
  emp.permissions = [];
  saveDb();
  res.json({ message: 'Đã xoá tài khoản đăng nhập' });
});

// ── Dashboard summary endpoint ──
app.get('/api/dashboard', authMiddleware, (req, res) => {
  const sid = req.user.storeId;
  const storePonds = sid ? db.ponds.filter(p => p.storeId === sid) : db.ponds;
  const storeTasks = sid ? db.tasks.filter(t => t.storeId === sid) : db.tasks;
  const storeProducts = sid ? db.products.filter(p => p.storeId === sid) : db.products;
  const storeCustomers = sid ? db.customers.filter(c => c.storeId === sid) : db.customers;
  const storeSales = sid ? db.saleorders.filter(o => o.storeId === sid) : db.saleorders;
  const storeBatches = sid ? db.fishbatches.filter(b => b.storeId === sid) : db.fishbatches;
  const storeNotifications = sid ? db.notifications.filter(n => !n.storeId || n.storeId === sid) : db.notifications;
  const storeEmployees = sid ? db.employees.filter(e => e.storeId === sid) : db.employees;

  const totalPonds = storePonds.length;
  const activePonds = storePonds.filter(p => p.status === 'active').length;
  const inactivePonds = storePonds.filter(p => p.status === 'inactive').length;
  const maintenancePonds = storePonds.filter(p => p.status === 'maintenance').length;
  const activeBatches = storeBatches.filter(b => b.status === 'active').length;
  const pendingTasks = storeTasks.filter(t => t.status === 'pending').length;
  const overdueTasks = storeTasks.filter(t => t.status === 'pending' && new Date(t.dueDate) < new Date()).length;
  const lowStockProducts = storeProducts.filter(p => p.stock <= p.minStock && p.minStock > 0).length;
  const totalCustomers = storeCustomers.length;
  const totalDebt = storeCustomers.reduce((s, c) => s + (c.debt || 0), 0);
  const pendingSales = storeSales.filter(o => o.status === 'pending').length;
  const unreadNotifications = storeNotifications.filter(n => !n.read).length;
  const phWarnings = storePonds.filter(p => p.currentPh != null && (p.currentPh > 8.5 || p.currentPh < 6.5)).length;
  const totalEmployees = storeEmployees.length;

  res.json({
    totalPonds, activePonds, inactivePonds, maintenancePonds,
    activeBatches, pendingTasks, overdueTasks, lowStockProducts,
    totalCustomers, totalDebt, pendingSales, unreadNotifications,
    phWarnings, totalEmployees,
    recentPonds: storePonds.slice(0, 5),
    todayTasks: storeTasks.filter(t => t.status === 'pending').slice(0, 5),
    alerts: storeNotifications.filter(n => !n.read).slice(0, 5),
  });
});

// ── Generic CRUD factory (with pagination support + store isolation) ──
// Cascade delete hooks per resource
const _cascadeDeleteHooks = {
  fishbatches: (id) => {
    db.sizemeasurements = db.sizemeasurements.filter(s => s.fishBatchId !== id);
    db.transfers = (db.transfers || []).filter(t => t.fishBatchId !== id);
    if (db.feedinglogs) db.feedinglogs = db.feedinglogs.filter(f => f.fishBatchId !== id);
    if (db.mortalitylogs) db.mortalitylogs = db.mortalitylogs.filter(m => m.fishBatchId !== id);
    if (db.harvests) db.harvests = db.harvests.filter(h => h.fishBatchId !== id);
  },
  products: (id) => {
    // Don't delete stock records, just clear references (keep history)
  },
  customers: (id) => {
    // Mark related sale orders as orphaned but don't delete
    db.saleorders.forEach(o => { if (o.customerId === id) o.customerId = ''; });
  },
  saleorders: (id) => {
    const order = db.saleorders.find(o => o._id === id);
    // Reverse customer debt if order was completed
    if (order && order.status === 'completed' && order.customerId) {
      const cust = db.customers.find(c => c._id === order.customerId);
      if (cust) cust.debt = Math.max(0, (cust.debt || 0) - (order.totalAmount || 0));
    }
    // Remove auto-created stock issues for this sale
    db.stockissues = db.stockissues.filter(si => si.saleOrderId !== id);
  },
  employees: (id) => {
    db.tasks.forEach(t => { if (t.assignedTo === id) t.assignedTo = ''; });
  },
  zones: (id) => {
    // Cascade: delete ponds in this zone (each pond triggers its own cascade)
    const pondIds = db.ponds.filter(p => p.zoneId === id).map(p => p._id);
    pondIds.forEach(pid => {
      // Clean up pond-related data (same as pond custom router delete)
      db.fishbatches = db.fishbatches.filter(b => b.pondId !== pid);
      db.tasks = db.tasks.filter(t => t.pondId !== pid);
      db.sensorreadings = db.sensorreadings.filter(s => s.pondId !== pid);
      db.transfers = (db.transfers || []).filter(t => t.fromPondId !== pid && t.toPondId !== pid);
      db.othercosts = db.othercosts.filter(c => c.pondId !== pid);
      if (db.feedinglogs) db.feedinglogs = db.feedinglogs.filter(f => f.pondId !== pid);
      if (db.mortalitylogs) db.mortalitylogs = db.mortalitylogs.filter(m => m.pondId !== pid);
      if (db.maintenancelogs) db.maintenancelogs = db.maintenancelogs.filter(m => m.pondId !== pid);
      db.diseaselogs = db.diseaselogs.filter(d => d.pondId !== pid);
      db.treatmentlogs = db.treatmentlogs.filter(t => t.pondId !== pid);
      db.equipment = db.equipment.filter(e => e.pondId !== pid);
      db.dailylogs = db.dailylogs.filter(d => d.pondId !== pid);
      db.waterchangelogs = db.waterchangelogs.filter(w => w.pondId !== pid);
      db.feedingschedules = db.feedingschedules.filter(f => f.pondId !== pid);
    });
    db.ponds = db.ponds.filter(p => p.zoneId !== id);
  },
  branches: (id) => {
    // Cascade: delete zones in this branch (each zone triggers its own cascade)
    const zoneIds = db.zones.filter(z => z.branchId === id).map(z => z._id);
    zoneIds.forEach(zid => {
      if (_cascadeDeleteHooks.zones) _cascadeDeleteHooks.zones(zid);
    });
    db.zones = db.zones.filter(z => z.branchId !== id);
    // Orphan employees — don't delete them, just clear branchId
    db.employees.forEach(e => { if (e.branchId === id) e.branchId = ''; });
  },
  species: (id) => {
    // Prevent deletion if active batches exist
    const activeBatches = db.fishbatches.filter(b => b.speciesId === id && b.status === 'active');
    if (activeBatches.length > 0) {
      throw new Error(`PREVENT_DELETE:Không thể xóa — còn ${activeBatches.length} lô cá đang nuôi`);
    }
    // Clear speciesId on completed/closed batches
    db.fishbatches.forEach(b => { if (b.speciesId === id) b.speciesId = ''; });
    db.cropcycles.forEach(c => { if (c.speciesId === id) c.speciesId = ''; });
  },
  suppliers: (id) => {
    // Orphan purchase orders
    db.purchaseorders.forEach(o => { if (o.supplierId === id) o.supplierId = ''; });
    // Orphan stock receipts
    db.stockreceipts.forEach(r => { if (r.supplierId === id) r.supplierId = ''; });
  },
};

function crudRoutes(resource) {
  const router = express.Router();
  router.use(authMiddleware);
  router.get('/', (req, res) => {
    let list = db[resource] || [];
    // Filter by storeId if the resource has it
    if (req.user.storeId) {
      list = list.filter(i => !i.storeId || i.storeId === req.user.storeId);
    }
    const page = parseInt(req.query.page) || 0;
    const limit = parseInt(req.query.limit) || 0;
    if (page > 0 && limit > 0) {
      const start = (page - 1) * limit;
      const paged = list.slice(start, start + limit);
      return res.json({ data: paged, total: list.length, page, limit });
    }
    res.json(list);
  });
  router.get('/:id', (req, res) => {
    const item = (db[resource] || []).find(i => i._id === req.params.id);
    if (!item) return res.status(404).json({ message: 'Not found' });
    if (item.storeId && req.user.storeId && item.storeId !== req.user.storeId) {
      return res.status(403).json({ message: 'Không có quyền truy cập' });
    }
    res.json(item);
  });
  router.post('/', (req, res) => {
    const item = { _id: genId(), ...req.body, storeId: req.user.storeId, createdAt: new Date().toISOString() };
    db[resource].push(item);
    saveDb();
    res.status(201).json(item);
  });
  router.put('/:id', (req, res) => {
    const idx = db[resource].findIndex(i => i._id === req.params.id);
    if (idx === -1) return res.status(404).json({ message: 'Not found' });
    if (db[resource][idx].storeId && req.user.storeId && db[resource][idx].storeId !== req.user.storeId) {
      return res.status(403).json({ message: 'Không có quyền chỉnh sửa' });
    }
    db[resource][idx] = { ...db[resource][idx], ...req.body };
    saveDb();
    res.json(db[resource][idx]);
  });
  router.delete('/:id', (req, res) => {
    const item = db[resource].find(i => i._id === req.params.id);
    if (item && item.storeId && req.user.storeId && item.storeId !== req.user.storeId) {
      return res.status(403).json({ message: 'Không có quyền xoá' });
    }
    // Run cascade delete hook if defined
    const hook = _cascadeDeleteHooks[resource];
    if (hook) {
      try { hook(req.params.id); } catch (e) {
        if (e.message && e.message.startsWith('PREVENT_DELETE:')) {
          return res.status(409).json({ message: e.message.replace('PREVENT_DELETE:', '') });
        }
        throw e;
      }
    }
    db[resource] = db[resource].filter(i => i._id !== req.params.id);
    saveDb();
    res.json({ message: 'Deleted' });
  });
  return router;
}

// ── SIZE MEASUREMENTS (custom – auto-update fishBatch weight/size) ──
const smRouter = express.Router();
smRouter.use(authMiddleware);
smRouter.get('/', (req, res) => {
  let list = db.sizemeasurements || [];
  if (req.query.storeId) list = list.filter(s => s.storeId === req.query.storeId);
  if (req.query.fishBatchId) list = list.filter(s => s.fishBatchId === req.query.fishBatchId);
  if (req.query.pondId) list = list.filter(s => s.pondId === req.query.pondId);
  res.json(list);
});
smRouter.post('/', (req, res) => {
  const item = { _id: genId(), ...req.body, createdAt: new Date().toISOString() };
  if (!db.sizemeasurements) db.sizemeasurements = [];
  db.sizemeasurements.push(item);
  // Auto-update fishBatch currentWeight + currentSize from this measurement
  if (item.fishBatchId) {
    const batch = (db.fishbatches || []).find(b => b._id === item.fishBatchId);
    if (batch) {
      if (item.avgWeight > 0) batch.currentWeight = item.avgWeight;
      if (item.avgLength > 0) batch.currentSize = item.avgLength;
      if (item.remainingQty > 0) batch.currentQuantity = item.remainingQty;
      batch.updatedAt = new Date().toISOString();
    }
  }
  saveDb();
  res.status(201).json(item);
});
smRouter.put('/:id', (req, res) => {
  const idx = (db.sizemeasurements || []).findIndex(s => s._id === req.params.id);
  if (idx === -1) return res.status(404).json({ error: 'Not found' });
  db.sizemeasurements[idx] = { ...db.sizemeasurements[idx], ...req.body, updatedAt: new Date().toISOString() };
  const updated = db.sizemeasurements[idx];
  // Also update fishBatch
  if (updated.fishBatchId) {
    const batch = (db.fishbatches || []).find(b => b._id === updated.fishBatchId);
    if (batch) {
      if (updated.avgWeight > 0) batch.currentWeight = updated.avgWeight;
      if (updated.avgLength > 0) batch.currentSize = updated.avgLength;
      batch.updatedAt = new Date().toISOString();
    }
  }
  saveDb();
  res.json(updated);
});
smRouter.delete('/:id', (req, res) => {
  if (!db.sizemeasurements) return res.status(404).json({ error: 'Not found' });
  const idx = db.sizemeasurements.findIndex(s => s._id === req.params.id);
  if (idx === -1) return res.status(404).json({ error: 'Not found' });
  db.sizemeasurements.splice(idx, 1);
  saveDb();
  res.json({ message: 'Deleted' });
});
app.use('/api/sizemeasurements', smRouter);

// ── Mount simple CRUD routes ──
const simpleResources = [
  'branches', 'zones', 'species', 'fishbatches',
  'products',
  'transfers', 'othercosts', 'employees', 'tasks', 'attendance',
  'customers',
  'suppliers', 'stocktakes', 'sensorreadings', 'auditlogs',
  'waterstandards', 'maintenancelogs',
  'diseaselogs', 'treatmentlogs', 'feedingschedules',
  'cropcycles', 'equipment', 'dailylogs', 'waterchangelogs',
];
simpleResources.forEach(r => app.use(`/api/${r}`, crudRoutes(r)));

// ── PONDS (custom – auto-create sensor readings on water param update) ──
const pondRouter = express.Router();
pondRouter.use(authMiddleware);
pondRouter.get('/', (req, res) => {
  let list = db.ponds;
  if (req.user.storeId) list = list.filter(p => !p.storeId || p.storeId === req.user.storeId);
  res.json(list);
});
pondRouter.get('/:id', (req, res) => {
  const item = db.ponds.find(i => i._id === req.params.id);
  item ? res.json(item) : res.status(404).json({ message: 'Not found' });
});
pondRouter.post('/', (req, res) => {
  const item = { _id: genId(), ...req.body, storeId: req.user.storeId, createdAt: new Date().toISOString() };
  db.ponds.push(item);
  saveDb();
  res.status(201).json(item);
});
pondRouter.put('/:id', (req, res) => {
  const idx = db.ponds.findIndex(i => i._id === req.params.id);
  if (idx === -1) return res.status(404).json({ message: 'Not found' });
  const old = db.ponds[idx];
  db.ponds[idx] = { ...old, ...req.body, updatedAt: new Date().toISOString() };
  const updated = db.ponds[idx];

  // Auto-create sensor reading when water params change
  const hasWaterChange = ['currentPh','currentDo','currentTemp','currentNh3','currentAlkalinity']
    .some(k => req.body[k] !== undefined && req.body[k] !== null && req.body[k] !== old[k]);
  if (hasWaterChange) {
    const reading = {
      _id: genId(),
      pondId: updated._id,
      pondCode: updated.code || '',
      timestamp: new Date().toISOString(),
      temperature: updated.currentTemp ?? null,
      pH: updated.currentPh ?? null,
      oxygen: updated.currentDo ?? null,
      nh3: updated.currentNh3 ?? null,
      alkalinity: updated.currentAlkalinity ?? null,
      measuredBy: updated.measuredBy || '',
      createdAt: new Date().toISOString(),
    };
    db.sensorreadings.push(reading);

    // Auto-generate notifications for out-of-range params
    _checkWaterAlerts(updated, req.user.storeId);
  }
  saveDb();
  res.json(updated);
});
pondRouter.delete('/:id', (req, res) => {
  const item = db.ponds.find(i => i._id === req.params.id);
  if (item && item.storeId && req.user.storeId && item.storeId !== req.user.storeId) {
    return res.status(403).json({ message: 'Không có quyền xoá' });
  }
  const pondId = req.params.id;
  // Cascade: remove related records
  db.fishbatches = db.fishbatches.filter(b => b.pondId !== pondId);
  db.tasks = db.tasks.filter(t => t.pondId !== pondId);
  db.sensorreadings = db.sensorreadings.filter(r => r.pondId !== pondId);
  db.transfers = (db.transfers || []).filter(t => t.fromPondId !== pondId && t.toPondId !== pondId);
  db.othercosts = (db.othercosts || []).filter(c => c.pondId !== pondId);
  if (db.feedinglogs) db.feedinglogs = db.feedinglogs.filter(f => f.pondId !== pondId);
  if (db.mortalitylogs) db.mortalitylogs = db.mortalitylogs.filter(m => m.pondId !== pondId);
  if (db.maintenancelogs) db.maintenancelogs = db.maintenancelogs.filter(m => m.pondId !== pondId);
  if (db.diseaselogs) db.diseaselogs = db.diseaselogs.filter(d => d.pondId !== pondId);
  if (db.treatmentlogs) db.treatmentlogs = db.treatmentlogs.filter(t => t.pondId !== pondId);
  if (db.dailylogs) db.dailylogs = db.dailylogs.filter(d => d.pondId !== pondId);
  if (db.waterchangelogs) db.waterchangelogs = db.waterchangelogs.filter(w => w.pondId !== pondId);
  db.sizemeasurements = db.sizemeasurements.filter(s => s.pondId !== pondId);
  db.stockissues = (db.stockissues || []).filter(si => si.pondId !== pondId);
  db.ponds = db.ponds.filter(i => i._id !== pondId);
  saveDb();
  res.json({ message: 'Deleted' });
});
app.use('/api/ponds', pondRouter);

// ── MAINTENANCE – Start maintenance with checklist, materials, tasks ──────
app.post('/api/maintenance/start', authMiddleware, (req, res) => {
  const { pondId, items, materials, note } = req.body;
  // items: [{ name, category }]  – checklist of maintenance work
  // materials: [{ productId, quantity }]  – materials to consume from warehouse

  const pond = db.ponds.find(p => p._id === pondId);
  if (!pond) return res.status(404).json({ message: 'Pond not found' });

  // 1) Create maintenance log
  const logId = genId();
  const log = {
    _id: logId,
    pondId,
    pondCode: pond.code,
    status: 'in_progress', // in_progress | completed | cancelled
    items: (items || []).map(it => ({ ...it, status: 'pending', completedAt: null })),
    materials: materials || [],
    note: note || '',
    startedAt: new Date().toISOString(),
    completedAt: null,
    createdAt: new Date().toISOString(),
    storeId: req.user.storeId || '',
  };
  if (!db.maintenancelogs) db.maintenancelogs = [];
  db.maintenancelogs.push(log);

  // 2) Update pond status to maintenance
  const pIdx = db.ponds.findIndex(p => p._id === pondId);
  if (pIdx !== -1) {
    db.ponds[pIdx] = { ...db.ponds[pIdx], status: 'maintenance', updatedAt: new Date().toISOString() };
  }

  // 3) Deduct materials from warehouse (with stock validation)
  const insufficientStock = [];
  (materials || []).forEach(m => {
    const prod = db.products.find(p => p._id === m.productId);
    if (prod) {
      if ((prod.stock || 0) < (m.quantity || 0)) {
        insufficientStock.push(`${prod.name}: còn ${prod.stock} ${prod.unit}, cần ${m.quantity}`);
      }
    }
  });
  if (insufficientStock.length > 0) {
    return res.status(400).json({ message: `Tồn kho không đủ:\n${insufficientStock.join('\n')}` });
  }
  (materials || []).forEach(m => {
    const prod = db.products.find(p => p._id === m.productId);
    if (prod) {
      prod.stock = Math.max(0, (prod.stock || 0) - (m.quantity || 0));
    }
  });

  // 4) Create tasks for each maintenance item
  (items || []).forEach(it => {
    const task = {
      _id: genId(),
      pondId,
      type: 'maintenance',
      title: `[BT] ${pond.code} – ${it.name}`,
      dueDate: new Date(Date.now() + 7 * 24 * 3600 * 1000).toISOString(), // 7 days default
      status: 'pending',
      note: `Hạng mục: ${it.name} (${it.category})`,
      assignedTo: req.user.id || '',
      maintenanceLogId: logId,
      createdAt: new Date().toISOString(),
    };
    db.tasks.push(task);
  });

  saveDb();
  res.status(201).json(log);
});

// ── MAINTENANCE – Update item progress ──
app.put('/api/maintenance/:logId/item/:itemIndex', authMiddleware, (req, res) => {
  if (!db.maintenancelogs) db.maintenancelogs = [];
  const log = db.maintenancelogs.find(l => l._id === req.params.logId);
  if (!log) return res.status(404).json({ message: 'Maintenance log not found' });

  const idx = parseInt(req.params.itemIndex);
  if (idx < 0 || idx >= (log.items || []).length) return res.status(400).json({ message: 'Invalid item index' });

  log.items[idx] = { ...log.items[idx], ...req.body, completedAt: req.body.status === 'done' ? new Date().toISOString() : null };

  // Check if all items done → auto-complete maintenance
  const allDone = log.items.every(it => it.status === 'done');
  if (allDone) {
    log.status = 'completed';
    log.completedAt = new Date().toISOString();
  } else {
    // If any item reverted, reopen maintenance
    if (log.status === 'completed') {
      log.status = 'in_progress';
      log.completedAt = null;
    }
  }

  // Calculate progress
  const doneCount = log.items.filter(it => it.status === 'done').length;
  log.progress = log.items.length > 0 ? Math.round((doneCount / log.items.length) * 100) : 0;

  saveDb();
  res.json(log);
});

// ── MAINTENANCE – Complete / Cancel maintenance ──
app.put('/api/maintenance/:logId/finish', authMiddleware, (req, res) => {
  if (!db.maintenancelogs) db.maintenancelogs = [];
  const log = db.maintenancelogs.find(l => l._id === req.params.logId);
  if (!log) return res.status(404).json({ message: 'Maintenance log not found' });

  log.status = req.body.status || 'completed'; // completed | cancelled
  log.completedAt = new Date().toISOString();
  log.note = req.body.note || log.note;

  // Update pond status back to inactive
  const pIdx = db.ponds.findIndex(p => p._id === log.pondId);
  if (pIdx !== -1) {
    db.ponds[pIdx] = { ...db.ponds[pIdx], status: 'inactive', updatedAt: new Date().toISOString() };
  }

  // Mark related tasks as done/cancelled
  db.tasks.forEach(t => {
    if (t.maintenanceLogId === log._id && t.status === 'pending') {
      t.status = log.status === 'completed' ? 'done' : 'cancelled';
    }
  });

  saveDb();
  res.json(log);
});

// ── Notification auto-generation ──────────────────────────────────────────
function _checkWaterAlerts(pond, storeId) {
  const alerts = [];
  if (pond.currentPh != null && (pond.currentPh > 8.5 || pond.currentPh < 6.5))
    alerts.push(`pH = ${pond.currentPh}${pond.currentPh > 8.5 ? ' (cao)' : ' (thấp)'}`);
  if (pond.currentDo != null && pond.currentDo < 3.0)
    alerts.push(`DO = ${pond.currentDo} mg/L (thấp)`);
  if (pond.currentNh3 != null && pond.currentNh3 > 0.1)
    alerts.push(`NH3 = ${pond.currentNh3} mg/L (cao)`);
  if (pond.currentTemp != null && (pond.currentTemp > 35 || pond.currentTemp < 20))
    alerts.push(`Nhiệt độ = ${pond.currentTemp}°C${pond.currentTemp > 35 ? ' (cao)' : ' (thấp)'}`);
  for (const msg of alerts) {
    // Dedup: skip if an unread notification for same pond + same param already exists
    const paramKey = msg.split('=')[0].trim(); // e.g. "pH", "DO", "NH3", "Nhiệt độ"
    const exists = db.notifications.find(n =>
      n.pondId === pond._id && !n.read && n.message && n.message.includes(paramKey)
    );
    if (exists) continue;
    db.notifications.push({
      _id: genId(),
      title: `Cảnh báo thông số nước ao ${pond.code}`,
      message: `Ao ${pond.code}: ${msg}`,
      type: 'warning',
      priority: 'high',
      pondId: pond._id,
      storeId: storeId || pond.storeId || '',
      read: false,
      createdAt: new Date().toISOString(),
    });
  }
  if (alerts.length > 0) saveDb();
}

// ── NOTIFICATIONS (custom routes – removed from simpleResources to avoid route conflict) ──

// GET all notifications (with storeId filter)
app.get('/api/notifications', authMiddleware, (req, res) => {
  let list = db.notifications || [];
  if (req.user.storeId) {
    list = list.filter(n => !n.storeId || n.storeId === req.user.storeId);
  }
  res.json(list);
});

// DELETE single notification
app.delete('/api/notifications/:id', authMiddleware, (req, res) => {
  const idx = (db.notifications || []).findIndex(n => n._id === req.params.id);
  if (idx === -1) return res.status(404).json({ message: 'Not found' });
  db.notifications.splice(idx, 1);
  saveDb();
  res.json({ message: 'Deleted' });
});

// Mark single notification as read
app.put('/api/notifications/:id/read', authMiddleware, (req, res) => {
  const n = db.notifications.find(i => i._id === req.params.id);
  if (!n) return res.status(404).json({ message: 'Not found' });
  n.read = true;
  saveDb();
  res.json(n);
});

// Mark all notifications as read
app.put('/api/notifications/read-all', authMiddleware, (req, res) => {
  let list = db.notifications;
  if (req.user.storeId) list = list.filter(n => !n.storeId || n.storeId === req.user.storeId);
  list.forEach(n => n.read = true);
  saveDb();
  res.json({ message: 'All marked as read', count: list.length });
});

// Delete all read notifications
app.delete('/api/notifications/clear-read', authMiddleware, (req, res) => {
  const before = db.notifications.length;
  let toRemove;
  if (req.user.storeId) {
    toRemove = db.notifications.filter(n => n.read === true && (!n.storeId || n.storeId === req.user.storeId));
  } else {
    toRemove = db.notifications.filter(n => n.read === true);
  }
  const ids = new Set(toRemove.map(n => n._id));
  db.notifications = db.notifications.filter(n => !ids.has(n._id));
  if (ids.size > 0) saveDb();
  res.json({ message: 'Cleared read notifications', removed: ids.size });
});

// Endpoint to check & generate system notifications
app.post('/api/notifications/check', authMiddleware, (req, res) => {
  const created = [];
  const now = new Date();
  const storeId = req.user.storeId;

  // ── AUTO-RESOLVE: mark old notifications as read when issue is resolved ──
  // Resolve overdue task notifications when task is completed/cancelled
  db.notifications.filter(n => !n.read && n.taskId && n.title === 'Công việc quá hạn').forEach(n => {
    const task = db.tasks.find(t => t._id === n.taskId);
    if (!task || task.status === 'done' || task.status === 'cancelled') n.read = true;
  });
  // Resolve low stock notifications when stock is replenished
  db.notifications.filter(n => !n.read && n.productId && (n.title === 'Tồn kho thấp' || n.title === 'Hết hàng')).forEach(n => {
    const prod = db.products.find(p => p._id === n.productId);
    if (!prod || (prod.minStock > 0 && prod.stock > prod.minStock) || prod.isActive === false) n.read = true;
  });
  // Resolve debt notifications when debt is paid
  db.notifications.filter(n => !n.read && n.customerId && n.title === 'Công nợ cao').forEach(n => {
    const cust = db.customers.find(c => c._id === n.customerId);
    if (!cust || (cust.debt || 0) <= 10000000) n.read = true;
  });
  // Resolve water alerts when params are back to normal
  db.notifications.filter(n => !n.read && n.pondId && n.title && n.title.startsWith('Cảnh báo thông số nước')).forEach(n => {
    const pond = db.ponds.find(p => p._id === n.pondId);
    if (!pond) { n.read = true; return; }
    const msg = n.message || '';
    if (msg.includes('pH') && pond.currentPh != null && pond.currentPh >= 6.5 && pond.currentPh <= 8.5) n.read = true;
    if (msg.includes('DO') && pond.currentDo != null && pond.currentDo >= 3.0) n.read = true;
    if (msg.includes('NH3') && pond.currentNh3 != null && pond.currentNh3 <= 0.1) n.read = true;
    if (msg.includes('Nhiệt độ') && pond.currentTemp != null && pond.currentTemp >= 20 && pond.currentTemp <= 35) n.read = true;
  });
  // Resolve transfer reminders when task is done
  db.notifications.filter(n => !n.read && n.taskId && (n.title === 'Nhắc chuyển cá' || n.title === 'Chuyển cá quá hạn')).forEach(n => {
    const task = db.tasks.find(t => t._id === n.taskId);
    if (!task || task.status === 'done' || task.status === 'cancelled') n.read = true;
  });
  // Resolve disease notifications when disease is treated/cured
  db.notifications.filter(n => !n.read && n.pondId && n.type === 'alert' && n.title && n.title.startsWith('Bệnh ')).forEach(n => {
    const titleMatch = n.title.match(/^Bệnh (.+) - Ao/);
    if (titleMatch) {
      const diseaseName = titleMatch[1];
      const activeDisease = (db.diseaselogs || []).find(d =>
        d.pondId === n.pondId && d.diseaseName === diseaseName && (d.status === 'detected' || d.status === 'treating')
      );
      if (!activeDisease) n.read = true;
    }
  });

  // ── GENERATE NEW NOTIFICATIONS (entity-level dedup: only if no unread exists) ──

  // 1) Overdue tasks
  const overdueTasks = db.tasks.filter(t =>
    t.status === 'pending' && new Date(t.dueDate) < now
  );
  for (const t of overdueTasks) {
    const exists = db.notifications.find(n =>
      n.taskId === t._id && n.title === 'Công việc quá hạn' && !n.read
    );
    if (!exists) {
      const n = {
        _id: genId(),
        title: 'Công việc quá hạn',
        message: `"${t.title}" đã quá hạn (${new Date(t.dueDate).toLocaleDateString('vi-VN')})`,
        type: 'warning',
        priority: 'high',
        taskId: t._id,
        pondId: t.pondId || '',
        read: false,
        createdAt: now.toISOString(),
      };
      if (storeId) n.storeId = storeId;
      db.notifications.push(n);
      created.push(n);
    }
  }

  // 2) Low stock / out of stock products
  const lowStock = db.products.filter(p => p.minStock > 0 && p.stock <= p.minStock && p.isActive !== false);
  for (const p of lowStock) {
    const exists = db.notifications.find(n =>
      n.productId === p._id && (n.title === 'Tồn kho thấp' || n.title === 'Hết hàng') && !n.read
    );
    if (!exists) {
      const isOut = p.stock <= 0;
      const n = {
        _id: genId(),
        title: isOut ? 'Hết hàng' : 'Tồn kho thấp',
        message: isOut
          ? `${p.name} đã hết hàng!`
          : `${p.name} còn ${p.stock} ${p.unit} (tối thiểu ${p.minStock})`,
        type: 'warning',
        priority: isOut ? 'high' : 'medium',
        productId: p._id,
        read: false,
        createdAt: now.toISOString(),
      };
      if (storeId) n.storeId = storeId;
      db.notifications.push(n);
      created.push(n);
    }
  }

  // 3) High customer debt
  const highDebt = db.customers.filter(c => (c.debt || 0) > 10000000);
  for (const c of highDebt) {
    const exists = db.notifications.find(n =>
      n.customerId === c._id && n.title === 'Công nợ cao' && !n.read
    );
    if (!exists) {
      const n = {
        _id: genId(),
        title: 'Công nợ cao',
        message: `${c.name} đang nợ ${(c.debt || 0).toLocaleString('vi-VN')}đ`,
        type: 'warning',
        priority: 'medium',
        customerId: c._id,
        read: false,
        createdAt: now.toISOString(),
      };
      if (storeId) n.storeId = storeId;
      db.notifications.push(n);
      created.push(n);
    }
  }

  // 4) Scheduled transfer reminders
  const transferTasks = db.tasks.filter(t =>
    t.type === 'transfer' && t.status === 'pending' && t.note
  );
  for (const t of transferTasks) {
    const rhMatch = t.note.match(/reminderHours:(\d+)/);
    const rh = rhMatch ? parseInt(rhMatch[1]) : 0;
    if (rh <= 0) continue;

    const dueDate = new Date(t.dueDate);
    const reminderTime = new Date(dueDate.getTime() - rh * 60 * 60 * 1000);

    if (now >= reminderTime && now <= dueDate) {
      const exists = db.notifications.find(n =>
        n.taskId === t._id && n.title === 'Nhắc chuyển cá' && !n.read
      );
      if (!exists) {
        const n = {
          _id: genId(),
          title: 'Nhắc chuyển cá',
          message: `${t.title} — lúc ${dueDate.toLocaleString('vi-VN')} (còn ${rh} giờ)`,
          type: 'info',
          priority: 'high',
          taskId: t._id,
          pondId: t.pondId || '',
          read: false,
          createdAt: now.toISOString(),
        };
        if (storeId) n.storeId = storeId;
        db.notifications.push(n);
        created.push(n);
      }
    }

    if (now > dueDate) {
      const exists = db.notifications.find(n =>
        n.taskId === t._id && n.title === 'Chuyển cá quá hạn' && !n.read
      );
      if (!exists) {
        const n = {
          _id: genId(),
          title: 'Chuyển cá quá hạn',
          message: `${t.title} — đã quá giờ hẹn (${dueDate.toLocaleString('vi-VN')})`,
          type: 'warning',
          priority: 'high',
          taskId: t._id,
          pondId: t.pondId || '',
          read: false,
          createdAt: now.toISOString(),
        };
        if (storeId) n.storeId = storeId;
        db.notifications.push(n);
        created.push(n);
      }
    }
  }

  // 5) Active disease alerts (merged from check-extended)
  (db.diseaselogs || []).filter(d => (!storeId || d.storeId === storeId) && (d.status === 'detected' || d.status === 'treating')).forEach(d => {
    const exists = db.notifications.find(n =>
      n.pondId === d.pondId && n.type === 'alert' && n.title && n.title.includes(d.diseaseName) && !n.read
    );
    if (!exists) {
      const pond = db.ponds.find(p => p._id === d.pondId);
      const n = {
        _id: genId(),
        title: `Bệnh ${d.diseaseName} - Ao ${pond?.code || '?'}`,
        message: `Phát hiện ${d.severity === 'severe' ? 'NGHIÊM TRỌNG' : d.severity === 'moderate' ? 'trung bình' : 'nhẹ'}. ${d.symptoms || ''}`,
        type: 'alert',
        priority: d.severity === 'severe' ? 'high' : 'medium',
        pondId: d.pondId,
        read: false,
        createdAt: now.toISOString(),
      };
      if (storeId) n.storeId = storeId;
      db.notifications.push(n);
      created.push(n);
    }
  });

  // 6) Withdrawal period warnings (merged from check-extended)
  (db.treatmentlogs || []).filter(t => (!storeId || t.storeId === storeId) && t.withdrawalDays > 0).forEach(t => {
    const endDate = t.endDate ? new Date(t.endDate) : new Date(new Date(t.startDate).getTime() + (t.durationDays || 1) * 86400000);
    const safeDate = new Date(endDate.getTime() + t.withdrawalDays * 86400000);
    if (now < safeDate) {
      const exists = db.notifications.find(n =>
        n.pondId === t.pondId && n.title && n.title.includes('cách ly') && n.title.includes(t.medicineName) && !n.read
      );
      if (!exists) {
        const pond = db.ponds.find(p => p._id === t.pondId);
        const n = {
          _id: genId(),
          title: `Thời gian cách ly ${t.medicineName} - Ao ${pond?.code || '?'}`,
          message: `Không thu hoạch trước ${safeDate.toLocaleDateString('vi-VN')}. Còn ${Math.ceil((safeDate - now) / 86400000)} ngày.`,
          type: 'warning',
          priority: 'high',
          pondId: t.pondId,
          read: false,
          createdAt: now.toISOString(),
        };
        if (storeId) n.storeId = storeId;
        db.notifications.push(n);
        created.push(n);
      }
    }
  });

  // 7) Equipment maintenance due (merged from check-extended)
  (db.equipment || []).filter(e => (!storeId || e.storeId === storeId) && e.status === 'active' && e.nextMaintenanceDate).forEach(e => {
    if (new Date(e.nextMaintenanceDate) <= now) {
      const exists = db.notifications.find(n =>
        n.title && n.title.includes(e.name) && n.title.includes('bảo trì') && !n.read
      );
      if (!exists) {
        const n = {
          _id: genId(),
          title: `Thiết bị ${e.name} cần bảo trì`,
          message: `Đã quá hạn bảo trì từ ${new Date(e.nextMaintenanceDate).toLocaleDateString('vi-VN')}`,
          type: 'warning',
          priority: 'medium',
          pondId: e.pondId || '',
          read: false,
          createdAt: now.toISOString(),
        };
        if (storeId) n.storeId = storeId;
        db.notifications.push(n);
        created.push(n);
      }
    }
  });

  // 8) High mortality rate batches (>15%)
  db.fishbatches.filter(b => b.status === 'active' && b.initialQuantity > 0).forEach(b => {
    const dead = b.mortalityCount || 0;
    const rate = dead / b.initialQuantity * 100;
    if (rate > 15) {
      const exists = db.notifications.find(n =>
        n.batchId === b._id && n.title && n.title.includes('hao hụt') && !n.read
      );
      if (!exists) {
        const pond = db.ponds.find(p => p._id === b.pondId);
        const n = {
          _id: genId(),
          title: `Tỷ lệ hao hụt cao - ${b.name}`,
          message: `Lô ${b.name} (Ao ${pond?.code || '?'}): ${rate.toFixed(1)}% hao hụt (${dead}/${b.initialQuantity} con)`,
          type: 'alert',
          priority: rate > 30 ? 'high' : 'medium',
          batchId: b._id,
          pondId: b.pondId || '',
          read: false,
          createdAt: now.toISOString(),
        };
        if (storeId) n.storeId = storeId;
        db.notifications.push(n);
        created.push(n);
      }
    }
  });

  if (created.length > 0) saveDb();
  res.json({ created: created.length, notifications: created });
});

// Sensor readings for a specific pond
app.get('/api/ponds/:id/readings', authMiddleware, (req, res) => {
  const readings = db.sensorreadings
    .filter(r => r.pondId === req.params.id)
    .sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));
  const limit = parseInt(req.query.limit) || 50;
  res.json(readings.slice(0, limit));
});

// ════════════════════════════════════════════════════════════════════════════
// BUSINESS LOGIC ROUTES – Cascade auto-operations
// ════════════════════════════════════════════════════════════════════════════

// helper: next code for a voucher sequence
function nextCode(prefix, list, field = 'code') {
  const nums = list.map(i => {
    const m = (i[field] || '').match(new RegExp(`^${prefix}-(\\d+)$`));
    return m ? parseInt(m[1], 10) : 0;
  });
  return `${prefix}-${String(Math.max(0, ...nums) + 1).padStart(3, '0')}`;
}

// ── SALE ORDERS ──────────────────────────────────────────────────────────
// When a sale order is completed:
//   1. Auto-create StockIssue (type=sale) to reduce product stock
//   2. Auto-increase Customer.debt by totalAmount
// When a payment voucher receipt is confirmed for this order, debt decreases.
const saleRouter = express.Router();
saleRouter.use(authMiddleware);
saleRouter.get('/', (req, res) => {
  let list = db.saleorders;
  if (req.user.storeId) list = list.filter(i => !i.storeId || i.storeId === req.user.storeId);
  res.json(list);
});
saleRouter.get('/:id', (req, res) => {
  const item = db.saleorders.find(i => i._id === req.params.id);
  item ? res.json(item) : res.status(404).json({ message: 'Not found' });
});
saleRouter.post('/', (req, res) => {
  const { customerId, items, totalAmount, status } = req.body;
  if (!customerId) return res.status(400).json({ message: 'Thiếu thông tin khách hàng' });
  if (!items || !Array.isArray(items) || items.length === 0) return res.status(400).json({ message: 'Đơn hàng phải có ít nhất 1 sản phẩm' });
  if (totalAmount != null && totalAmount < 0) return res.status(400).json({ message: 'Tổng tiền không được âm' });
  // Validate customer exists
  const customer = db.customers.find(c => c._id === customerId);
  if (!customer) return res.status(400).json({ message: 'Khách hàng không tồn tại' });
  // Validate items have positive qty
  for (const it of items) {
    if (!it.qty || it.qty <= 0) return res.status(400).json({ message: 'Số lượng sản phẩm phải > 0' });
  }
  const item = { _id: genId(), ...req.body, storeId: req.user.storeId, createdAt: new Date().toISOString() };
  db.saleorders.push(item);

  // If created with status completed, trigger cascades
  if (item.status === 'completed') {
    _onSaleCompleted(item);
  }
  saveDb();
  res.status(201).json(item);
});
saleRouter.put('/:id', (req, res) => {
  const idx = db.saleorders.findIndex(i => i._id === req.params.id);
  if (idx === -1) return res.status(404).json({ message: 'Not found' });
  if (db.saleorders[idx].storeId && req.user.storeId && db.saleorders[idx].storeId !== req.user.storeId) {
    return res.status(403).json({ message: 'Không có quyền chỉnh sửa' });
  }
  const oldStatus = db.saleorders[idx].status;
  db.saleorders[idx] = { ...db.saleorders[idx], ...req.body };
  const updated = db.saleorders[idx];

  // Trigger cascade when status changes to completed
  if (oldStatus !== 'completed' && updated.status === 'completed') {
    _onSaleCompleted(updated);
  }
  saveDb();
  res.json(updated);
});
saleRouter.delete('/:id', (req, res) => {
  const item = db.saleorders.find(i => i._id === req.params.id);
  if (item && item.storeId && req.user.storeId && item.storeId !== req.user.storeId) {
    return res.status(403).json({ message: 'Không có quyền xoá' });
  }
  // Reverse customer debt if order was completed
  if (item && item.status === 'completed' && item.customerId) {
    const cust = db.customers.find(c => c._id === item.customerId);
    if (cust) cust.debt = Math.max(0, (cust.debt || 0) - (item.totalAmount || 0));
  }
  // Remove auto-created stock issues for this sale
  db.stockissues = db.stockissues.filter(si => si.saleOrderId !== req.params.id);
  db.saleorders = db.saleorders.filter(i => i._id !== req.params.id);
  saveDb();
  res.json({ message: 'Deleted' });
});

function _onSaleCompleted(order) {
  // 0) Deduct fish from fishBatch
  if (order.fishBatchId && order.items && order.items.length > 0) {
    const batch = db.fishbatches.find(b => b._id === order.fishBatchId);
    if (batch) {
      const totalSold = order.items.reduce((s, it) => s + (it.qty || it.quantity || 0), 0);
      batch.currentQuantity = Math.max(0, (batch.currentQuantity || 0) - totalSold);
      // Update pondAllocations
      if (batch.pondAllocations && order.pondId) {
        const alloc = batch.pondAllocations.find(a => a.pondId === order.pondId);
        if (alloc) {
          alloc.quantity = Math.max(0, (alloc.quantity || 0) - totalSold);
          if (alloc.quantity <= 0) batch.pondAllocations = batch.pondAllocations.filter(a => a.pondId !== order.pondId);
        }
      }
      if (batch.currentQuantity <= 0) batch.status = 'harvested';
      batch.updatedAt = new Date().toISOString();
    }
  }

  // 1) Auto-create StockIssue for sale items
  if (order.items && order.items.length > 0) {
    const issueItems = order.items.map(it => ({
      productId: it.productId || '',
      productName: it.productName || it.product || '',
      qty: it.qty || it.quantity || 0,
      unitPrice: it.price || it.unitPrice || 0,
      unit: it.unit || 'kg',
    }));
    const stockIssue = {
      _id: genId(),
      code: nextCode('XK', db.stockissues),
      date: new Date().toISOString(),
      type: 'sale',
      saleOrderId: order._id,
      pondId: order.pondId || '',
      branchId: order.branchId || '1',
      items: issueItems,
      totalAmount: order.totalAmount || 0,
      status: 'approved',
      note: `Xuất kho tự động cho đơn bán #${order._id}`,
      createdBy: order.createdBy || '1',
      issuedTo: '',
      approvedBy: order.createdBy || '1',
      createdAt: new Date().toISOString(),
    };
    db.stockissues.push(stockIssue);

    // Decrease product stock
    for (const it of issueItems) {
      if (it.productId) {
        const prod = db.products.find(p => p._id === it.productId);
        if (prod) prod.stock = Math.max(0, (prod.stock || 0) - (it.qty || 0));
      }
    }
  }

  // 2) Increase customer debt
  if (order.customerId && order.totalAmount > 0) {
    const cust = db.customers.find(c => c._id === order.customerId);
    if (cust) cust.debt = (cust.debt || 0) + order.totalAmount;
  }
}

app.use('/api/saleorders', saleRouter);

// ── PURCHASE ORDERS ──────────────────────────────────────────────────────
// When a PO status changes to 'completed':
//   1. Auto-create PaymentVoucher (type=payment, category=mua_hang)
const poRouter = express.Router();
poRouter.use(authMiddleware);
poRouter.get('/', (req, res) => {
  let list = db.purchaseorders;
  if (req.user.storeId) list = list.filter(i => !i.storeId || i.storeId === req.user.storeId);
  res.json(list);
});
poRouter.get('/:id', (req, res) => {
  const item = db.purchaseorders.find(i => i._id === req.params.id);
  item ? res.json(item) : res.status(404).json({ message: 'Not found' });
});
poRouter.post('/', (req, res) => {
  const item = { _id: genId(), ...req.body, createdAt: new Date().toISOString() };
  db.purchaseorders.push(item);
  saveDb();
  res.status(201).json(item);
});
poRouter.put('/:id', (req, res) => {
  const idx = db.purchaseorders.findIndex(i => i._id === req.params.id);
  if (idx === -1) return res.status(404).json({ message: 'Not found' });
  if (db.purchaseorders[idx].storeId && req.user.storeId && db.purchaseorders[idx].storeId !== req.user.storeId) {
    return res.status(403).json({ message: 'Không có quyền chỉnh sửa' });
  }
  const oldStatus = db.purchaseorders[idx].status;
  db.purchaseorders[idx] = { ...db.purchaseorders[idx], ...req.body };
  const updated = db.purchaseorders[idx];

  // NOTE: Payment voucher is now created by frontend during receipt approval
  // _onPOCompleted is no longer called here to avoid duplicate vouchers
  saveDb();
  res.json(updated);
});
poRouter.delete('/:id', (req, res) => {
  const item = db.purchaseorders.find(i => i._id === req.params.id);
  if (item && item.storeId && req.user.storeId && item.storeId !== req.user.storeId) {
    return res.status(403).json({ message: 'Không có quyền xoá' });
  }
  db.purchaseorders = db.purchaseorders.filter(i => i._id !== req.params.id);
  saveDb();
  res.json({ message: 'Deleted' });
});

app.use('/api/purchaseorders', poRouter);

// ── STOCK RECEIPTS ───────────────────────────────────────────────────────
// When a stock receipt is approved:
//   1. Increase Product.stock by receivedQty for each item
const srRouter = express.Router();
srRouter.use(authMiddleware);
srRouter.get('/', (req, res) => {
  let list = db.stockreceipts;
  if (req.user.storeId) list = list.filter(i => !i.storeId || i.storeId === req.user.storeId);
  res.json(list);
});
srRouter.get('/:id', (req, res) => {
  const item = db.stockreceipts.find(i => i._id === req.params.id);
  item ? res.json(item) : res.status(404).json({ message: 'Not found' });
});
srRouter.post('/', (req, res) => {
  const item = { _id: genId(), ...req.body, createdAt: new Date().toISOString() };
  db.stockreceipts.push(item);
  if (item.status === 'approved') _onReceiptApproved(item);
  saveDb();
  res.status(201).json(item);
});
srRouter.put('/:id', (req, res) => {
  const idx = db.stockreceipts.findIndex(i => i._id === req.params.id);
  if (idx === -1) return res.status(404).json({ message: 'Not found' });
  if (db.stockreceipts[idx].storeId && req.user.storeId && db.stockreceipts[idx].storeId !== req.user.storeId) {
    return res.status(403).json({ message: 'Không có quyền chỉnh sửa' });
  }
  const oldStatus = db.stockreceipts[idx].status;
  db.stockreceipts[idx] = { ...db.stockreceipts[idx], ...req.body };
  const updated = db.stockreceipts[idx];

  if (oldStatus !== 'approved' && updated.status === 'approved') {
    _onReceiptApproved(updated);
  }
  saveDb();
  res.json(updated);
});
srRouter.delete('/:id', (req, res) => {
  const item = db.stockreceipts.find(i => i._id === req.params.id);
  if (item && item.storeId && req.user.storeId && item.storeId !== req.user.storeId) {
    return res.status(403).json({ message: 'Kh\u00f4ng c\u00f3 quy\u1ec1n xo\u00e1' });
  }
  // Reverse stock if receipt was approved
  if (item && item._stockProcessed && item.items) {
    for (const it of item.items) {
      if (it.productId) {
        const prod = db.products.find(p => p._id === it.productId);
        if (prod) prod.stock = Math.max(0, (prod.stock || 0) - (it.receivedQty || it.qty || 0));
      }
    }
  }
  db.stockreceipts = db.stockreceipts.filter(i => i._id !== req.params.id);
  saveDb();
  res.json({ message: 'Deleted' });
});

function _onReceiptApproved(receipt) {
  if (!receipt.items) return;
  // Prevent duplicate processing
  if (receipt._stockProcessed) return;
  receipt._stockProcessed = true;
  for (const it of receipt.items) {
    if (it.productId) {
      const prod = db.products.find(p => p._id === it.productId);
      if (prod) {
        const receivedQty = it.receivedQty || it.qty || 0;
        const oldStock = prod.stock || 0;
        const oldCost = prod.costPrice || 0;
        const newUnitPrice = it.unitPrice || 0;

        // Update costPrice using weighted average
        if (newUnitPrice > 0) {
          if (oldStock > 0 && oldCost > 0) {
            prod.costPrice = Math.round((oldStock * oldCost + receivedQty * newUnitPrice) / (oldStock + receivedQty));
          } else {
            prod.costPrice = newUnitPrice;
          }
        }

        prod.stock = oldStock + receivedQty;
      }
    }
  }
}

app.use('/api/stockreceipts', srRouter);

// ── STOCK ISSUES ─────────────────────────────────────────────────────────
// When a stock issue is approved:
//   1. Decrease Product.stock by qty for each item
//   2. If type='usage' and pondId set → update FishBatch.feedConsumed
const siRouter = express.Router();
siRouter.use(authMiddleware);
siRouter.get('/', (req, res) => {
  let list = db.stockissues;
  if (req.user.storeId) list = list.filter(i => !i.storeId || i.storeId === req.user.storeId);
  res.json(list);
});
siRouter.get('/:id', (req, res) => {
  const item = db.stockissues.find(i => i._id === req.params.id);
  item ? res.json(item) : res.status(404).json({ message: 'Not found' });
});
siRouter.post('/', (req, res) => {
  const item = { _id: genId(), ...req.body, createdAt: new Date().toISOString() };
  db.stockissues.push(item);
  if (item.status === 'approved') _onIssueApproved(item);
  saveDb();
  res.status(201).json(item);
});
siRouter.put('/:id', (req, res) => {
  const idx = db.stockissues.findIndex(i => i._id === req.params.id);
  if (idx === -1) return res.status(404).json({ message: 'Not found' });
  if (db.stockissues[idx].storeId && req.user.storeId && db.stockissues[idx].storeId !== req.user.storeId) {
    return res.status(403).json({ message: 'Không có quyền chỉnh sửa' });
  }
  const oldStatus = db.stockissues[idx].status;
  db.stockissues[idx] = { ...db.stockissues[idx], ...req.body };
  const updated = db.stockissues[idx];

  if (oldStatus !== 'approved' && updated.status === 'approved') {
    _onIssueApproved(updated);
  }
  saveDb();
  res.json(updated);
});
siRouter.delete('/:id', (req, res) => {
  const item = db.stockissues.find(i => i._id === req.params.id);
  if (item && item.storeId && req.user.storeId && item.storeId !== req.user.storeId) {
    return res.status(403).json({ message: 'Kh\u00f4ng c\u00f3 quy\u1ec1n xo\u00e1' });
  }
  // Reverse stock deduction if issue was processed
  if (item && item._stockProcessed && item.items) {
    for (const it of item.items) {
      if (it.productId) {
        const prod = db.products.find(p => p._id === it.productId);
        if (prod) prod.stock = (prod.stock || 0) + (it.qty || 0);
      }
    }
  }
  db.stockissues = db.stockissues.filter(i => i._id !== req.params.id);
  saveDb();
  res.json({ message: 'Deleted' });
});

function _onIssueApproved(issue) {
  if (!issue.items) return;
  // Prevent duplicate processing
  if (issue._stockProcessed) return;
  issue._stockProcessed = true;

  // 1) Decrease product stock
  for (const it of issue.items) {
    if (it.productId) {
      const prod = db.products.find(p => p._id === it.productId);
      if (prod) prod.stock = Math.max(0, (prod.stock || 0) - (it.qty || 0));
    }
  }

  // 2) If usage type with pondId → update feedConsumed on active batches
  //    (Only for type='usage', NOT 'feeding' – feeding logs handle their own feedConsumed)
  if (issue.type === 'usage' && issue.pondId) {
    const feedItems = issue.items.filter(it => {
      const prod = db.products.find(p => p._id === it.productId);
      return prod && prod.category === 'feed';
    });
    const totalFeedKg = feedItems.reduce((s, it) => s + (it.qty || 0), 0);
    if (totalFeedKg > 0) {
      const activeBatches = db.fishbatches.filter(
        b => b.pondId === issue.pondId && b.status === 'active'
      );
      const perBatch = totalFeedKg / (activeBatches.length || 1);
      for (const batch of activeBatches) {
        batch.feedConsumed = (batch.feedConsumed || 0) + perBatch;
        batch.updatedAt = new Date().toISOString();
      }
    }
  }

  // 3) If feeding type → update feedConsumed + create feeding log
  if (issue.type === 'feeding' && issue.pondId) {
    // Update feedConsumed on active batches in this pond
    const totalFeedKg = issue.items.reduce((s, it) => s + (it.qty || 0), 0);
    if (totalFeedKg > 0) {
      const activeBatches = db.fishbatches.filter(b => {
        if (b.status !== 'active') return false;
        if (b.pondAllocations && b.pondAllocations.length > 0) return b.pondAllocations.some(a => a.pondId === issue.pondId);
        return b.pondId === issue.pondId;
      });
      const perBatch = totalFeedKg / (activeBatches.length || 1);
      for (const batch of activeBatches) {
        batch.feedConsumed = (batch.feedConsumed || 0) + perBatch;
        batch.updatedAt = new Date().toISOString();
      }
    }
    // Create feeding log entries
    if (!db.feedinglogs) db.feedinglogs = [];
    for (const it of issue.items) {
      const prod = it.productId ? db.products.find(p => p._id === it.productId) : null;
      const log = {
        _id: genId(),
        pondId: issue.pondId,
        fishBatchId: issue.fishBatchId || '',
        productId: it.productId || '',
        productName: it.productName || (prod ? prod.name : ''),
        quantity: it.qty || 0,
        unit: it.unit || (prod ? prod.unit : 'kg'),
        date: issue.date || new Date().toISOString(),
        note: issue.note || '',
        stockIssueId: issue._id,
        storeId: issue.storeId || '',
        createdBy: issue.approvedBy || issue.createdBy || '',
        createdAt: new Date().toISOString(),
      };
      db.feedinglogs.push(log);
    }
  }
}

app.use('/api/stockissues', siRouter);

// ── PAYMENT VOUCHERS ─────────────────────────────────────────────────────
// When a receipt voucher is confirmed:
//   1. If contactType='customer' → decrease Customer.debt by amount
// When a payment voucher is confirmed:
//   (auto-created by PO completion, no extra cascade needed)
const pvRouter = express.Router();
pvRouter.use(authMiddleware);
pvRouter.get('/', (req, res) => {
  let list = db.paymentvouchers;
  if (req.user.storeId) list = list.filter(i => !i.storeId || i.storeId === req.user.storeId);
  res.json(list);
});
pvRouter.get('/:id', (req, res) => {
  const item = db.paymentvouchers.find(i => i._id === req.params.id);
  item ? res.json(item) : res.status(404).json({ message: 'Not found' });
});
pvRouter.post('/', (req, res) => {
  const item = { _id: genId(), ...req.body, createdAt: new Date().toISOString() };
  db.paymentvouchers.push(item);
  if (item.status === 'confirmed') _onVoucherConfirmed(item);
  res.status(201).json(item);
});
pvRouter.put('/:id', (req, res) => {
  const idx = db.paymentvouchers.findIndex(i => i._id === req.params.id);
  if (idx === -1) return res.status(404).json({ message: 'Not found' });
  const oldStatus = db.paymentvouchers[idx].status;
  db.paymentvouchers[idx] = { ...db.paymentvouchers[idx], ...req.body };
  const updated = db.paymentvouchers[idx];

  if (oldStatus !== 'confirmed' && updated.status === 'confirmed') {
    _onVoucherConfirmed(updated);
  }
  res.json(updated);
});
pvRouter.delete('/:id', (req, res) => {
  db.paymentvouchers = db.paymentvouchers.filter(i => i._id !== req.params.id);
  res.json({ message: 'Deleted' });
});

function _onVoucherConfirmed(voucher) {
  // Prevent duplicate processing
  if (voucher._debtProcessed) return;
  voucher._debtProcessed = true;
  // Receipt from customer → decrease customer debt
  if (voucher.type === 'receipt' && voucher.contactType === 'customer' && voucher.contactId) {
    const cust = db.customers.find(c => c._id === voucher.contactId);
    if (cust) {
      cust.debt = Math.max(0, (cust.debt || 0) - (voucher.amount || 0));
    }
  }
}

// Audit log wrapper for payment voucher mutations
function _auditPV(action, voucher, oldData, userId) {
  db.auditlogs.push({
    _id: genId(),
    resource: 'paymentvouchers',
    resourceId: voucher._id,
    action, // 'create' | 'update' | 'delete' | 'confirm'
    code: voucher.code || oldData?.code || '',
    userId: userId || voucher.createdBy || '',
    oldData: oldData || null,
    newData: action === 'delete' ? null : { ...voucher },
    timestamp: new Date().toISOString(),
  });
}

// Override pvRouter handlers to add audit logging
const _origPvPost = pvRouter.stack.find(l => l.route?.methods?.post);
const _origPvPut = pvRouter.stack.find(l => l.route?.methods?.put && l.route.path === '/:id');
const _origPvDel = pvRouter.stack.find(l => l.route?.methods?.delete);

// Wrap POST
pvRouter.stack = pvRouter.stack.filter(l => !l.route?.methods?.post);
pvRouter.post('/', (req, res) => {
  const item = { _id: genId(), ...req.body, createdAt: new Date().toISOString() };
  db.paymentvouchers.push(item);
  _auditPV('create', item, null, req.body.createdBy);
  if (item.status === 'confirmed') _onVoucherConfirmed(item);
  saveDb();
  res.status(201).json(item);
});

// Wrap PUT
pvRouter.stack = pvRouter.stack.filter(l => !(l.route?.methods?.put && l.route.path === '/:id'));
pvRouter.put('/:id', (req, res) => {
  const idx = db.paymentvouchers.findIndex(i => i._id === req.params.id);
  if (idx === -1) return res.status(404).json({ message: 'Not found' });
  const old = { ...db.paymentvouchers[idx] };
  const oldStatus = old.status;
  db.paymentvouchers[idx] = { ...old, ...req.body };
  const updated = db.paymentvouchers[idx];
  const action = (oldStatus !== 'confirmed' && updated.status === 'confirmed') ? 'confirm' : 'update';
  _auditPV(action, updated, old, req.body.approvedBy || req.body.createdBy);
  if (oldStatus !== 'confirmed' && updated.status === 'confirmed') {
    _onVoucherConfirmed(updated);
  }
  saveDb();
  res.json(updated);
});

// Wrap DELETE
pvRouter.stack = pvRouter.stack.filter(l => !l.route?.methods?.delete);
pvRouter.delete('/:id', (req, res) => {
  const item = db.paymentvouchers.find(i => i._id === req.params.id);
  if (item) _auditPV('delete', item, item, '');
  db.paymentvouchers = db.paymentvouchers.filter(i => i._id !== req.params.id);
  saveDb();
  res.json({ message: 'Deleted' });
});

app.use('/api/paymentvouchers', pvRouter);

// Audit log endpoint for viewing financial audit trail
app.get('/api/auditlogs/paymentvouchers', authMiddleware, (req, res) => {
  const logs = db.auditlogs
    .filter(l => l.resource === 'paymentvouchers')
    .sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));
  const page = parseInt(req.query.page) || 0;
  const limit = parseInt(req.query.limit) || 50;
  if (page > 0) {
    const start = (page - 1) * limit;
    return res.json({ data: logs.slice(start, start + limit), total: logs.length, page, limit });
  }
  res.json(logs.slice(0, limit));
});

// ════════════════════════════════════════════════════════════════════════════
// EXPORT – CSV endpoints for all resources
// ════════════════════════════════════════════════════════════════════════════

function toCsv(rows, columns) {
  if (!rows.length) return columns.map(c => c.label).join(',') + '\n';
  const header = columns.map(c => `"${c.label}"`).join(',');
  const body = rows.map(r => columns.map(c => {
    let v = c.key.split('.').reduce((o, k) => (o && o[k] !== undefined) ? o[k] : '', r);
    if (v === null || v === undefined) v = '';
    if (Array.isArray(v)) v = v.length;
    return `"${String(v).replace(/"/g, '""')}"`;
  }).join(',')).join('\n');
  return '\uFEFF' + header + '\n' + body;
}

const exportConfigs = {
  ponds: { data: () => db.ponds, columns: [
    {key:'code',label:'Mã ao'},{key:'zoneId',label:'Khu'},{key:'area',label:'Diện tích (m²)'},{key:'volume',label:'Thể tích (m³)'},{key:'depth',label:'Độ sâu (m)'},{key:'type',label:'Loại'},{key:'status',label:'Trạng thái'},{key:'currentPh',label:'pH'},{key:'currentDo',label:'DO'},{key:'currentTemp',label:'Nhiệt độ'},{key:'currentNh3',label:'NH3'},{key:'createdAt',label:'Ngày tạo'}
  ]},
  fishbatches: { data: () => db.fishbatches, columns: [
    {key:'pondId',label:'Ao'},{key:'speciesId',label:'Loài'},{key:'stockingDate',label:'Ngày thả'},{key:'initialQuantity',label:'SL ban đầu'},{key:'currentQuantity',label:'SL hiện tại'},{key:'currentWeight',label:'Trọng lượng (g)'},{key:'mortalityQuantity',label:'Hao hụt'},{key:'feedConsumed',label:'Thức ăn (kg)'},{key:'status',label:'Trạng thái'},{key:'expectedHarvestDate',label:'Ngày thu hoạch dự kiến'}
  ]},
  products: { data: () => db.products, columns: [
    {key:'sku',label:'Mã SKU'},{key:'name',label:'Tên'},{key:'category',label:'Danh mục'},{key:'unit',label:'Đơn vị'},{key:'price',label:'Giá'},{key:'stock',label:'Tồn kho'},{key:'minStock',label:'Tồn tối thiểu'}
  ]},
  employees: { data: () => db.employees, columns: [
    {key:'name',label:'Họ tên'},{key:'email',label:'Email'},{key:'phone',label:'SĐT'},{key:'role',label:'Vai trò'},{key:'branchId',label:'Chi nhánh'},{key:'shift',label:'Ca làm'},{key:'hasAccount',label:'Có tài khoản'}
  ]},
  tasks: { data: () => db.tasks, columns: [
    {key:'title',label:'Tiêu đề'},{key:'type',label:'Loại'},{key:'assignedTo',label:'Giao cho'},{key:'pondId',label:'Ao'},{key:'dueDate',label:'Hạn'},{key:'status',label:'Trạng thái'},{key:'note',label:'Ghi chú'}
  ]},
  customers: { data: () => db.customers, columns: [
    {key:'name',label:'Tên'},{key:'type',label:'Loại'},{key:'address',label:'Địa chỉ'},{key:'contact',label:'Liên hệ'},{key:'debt',label:'Công nợ'}
  ]},
  suppliers: { data: () => db.suppliers, columns: [
    {key:'name',label:'Tên'},{key:'phone',label:'SĐT'},{key:'email',label:'Email'},{key:'address',label:'Địa chỉ'},{key:'taxCode',label:'MST'},{key:'debt',label:'Công nợ'}
  ]},
  saleorders: { data: () => db.saleorders, columns: [
    {key:'_id',label:'Mã'},{key:'customerId',label:'Khách'},{key:'date',label:'Ngày'},{key:'totalAmount',label:'Tổng tiền'},{key:'status',label:'Trạng thái'}
  ]},
  purchaseorders: { data: () => db.purchaseorders, columns: [
    {key:'code',label:'Mã'},{key:'supplierId',label:'NCC'},{key:'date',label:'Ngày'},{key:'total',label:'Tổng tiền'},{key:'status',label:'Trạng thái'}
  ]},
  paymentvouchers: { data: () => db.paymentvouchers, columns: [
    {key:'code',label:'Mã'},{key:'type',label:'Loại'},{key:'category',label:'Danh mục'},{key:'amount',label:'Số tiền'},{key:'contactName',label:'Đối tác'},{key:'date',label:'Ngày'},{key:'status',label:'Trạng thái'}
  ]},
  stockreceipts: { data: () => db.stockreceipts, columns: [
    {key:'code',label:'Mã'},{key:'date',label:'Ngày'},{key:'type',label:'Loại'},{key:'totalAmount',label:'Tổng tiền'},{key:'status',label:'Trạng thái'}
  ]},
  stockissues: { data: () => db.stockissues, columns: [
    {key:'code',label:'Mã'},{key:'date',label:'Ngày'},{key:'type',label:'Loại'},{key:'totalAmount',label:'Tổng tiền'},{key:'status',label:'Trạng thái'}
  ]},
  attendance: { data: () => db.attendance, columns: [
    {key:'employeeId',label:'NV'},{key:'date',label:'Ngày'},{key:'shift',label:'Ca'},{key:'timeIn',label:'Vào'},{key:'timeOut',label:'Ra'}
  ]},
  sensorreadings: { data: () => db.sensorreadings, columns: [
    {key:'pondId',label:'Ao'},{key:'timestamp',label:'Thời gian'},{key:'temperature',label:'Nhiệt độ'},{key:'pH',label:'pH'},{key:'oxygen',label:'DO'},{key:'nh3',label:'NH3'},{key:'alkalinity',label:'Kiềm'}
  ]},
};

app.get('/api/export/:resource', authMiddleware, (req, res) => {
  const resource = req.params.resource;
  const config = exportConfigs[resource];
  if (!config) return res.status(404).json({ message: 'Không hỗ trợ xuất dữ liệu cho: ' + resource });
  let data = config.data();
  const sid = req.user.storeId;
  if (sid) data = data.filter(i => !i.storeId || i.storeId === sid);
  const csv = toCsv(data, config.columns);
  res.setHeader('Content-Type', 'text/csv; charset=utf-8');
  res.setHeader('Content-Disposition', `attachment; filename=${resource}_${new Date().toISOString().slice(0,10)}.csv`);
  res.send(csv);
});

// ════════════════════════════════════════════════════════════════════════════
// HARVEST WORKFLOW
// ════════════════════════════════════════════════════════════════════════════

app.post('/api/harvest', authMiddleware, (req, res) => {
  const { fishBatchId, harvestDate, harvestQuantity, harvestWeight, pricePerKg, buyerName, note } = req.body;
  if (!fishBatchId) return res.status(400).json({ message: 'Thiếu thông tin lô cá' });
  if (harvestQuantity != null && harvestQuantity <= 0) return res.status(400).json({ message: 'Số lượng thu hoạch phải > 0' });
  if (harvestWeight != null && harvestWeight < 0) return res.status(400).json({ message: 'Trọng lượng thu hoạch không được âm' });
  const sid = req.user.storeId;
  const batch = db.fishbatches.find(b => b._id === fishBatchId && b.storeId === sid);
  if (!batch) return res.status(404).json({ message: 'Không tìm thấy lô cá' });
  if (batch.status !== 'active') return res.status(400).json({ message: 'Lô cá không ở trạng thái hoạt động' });

  const qty = harvestQuantity || batch.currentQuantity;
  const weight = harvestWeight || (qty * (batch.currentWeight || 0) / 1000);
  const totalRevenue = (weight * (pricePerKg || 0));

  // Create harvest record
  const harvest = {
    _id: genId(),
    fishBatchId,
    pondId: batch.pondId,
    speciesId: batch.speciesId,
    harvestDate: harvestDate || new Date().toISOString(),
    harvestQuantity: qty,
    harvestWeightKg: weight,
    pricePerKg: pricePerKg || 0,
    totalRevenue,
    buyerName: buyerName || '',
    note: note || '',
    storeId: sid,
    createdBy: req.user.id,
    createdAt: new Date().toISOString(),
  };
  if (!db.harvests) db.harvests = [];
  db.harvests.push(harvest);

  // Update batch
  batch.currentQuantity = Math.max(0, (batch.currentQuantity || 0) - qty);
  if (batch.currentQuantity === 0) {
    batch.status = 'harvested';
  }
  batch.updatedAt = new Date().toISOString();

  // Update pond status if all batches done
  const activeBatches = db.fishbatches.filter(b => b.pondId === batch.pondId && b.status === 'active');
  if (activeBatches.length === 0) {
    const pond = db.ponds.find(p => p._id === batch.pondId);
    if (pond) pond.status = 'inactive';
  }

  saveDb();
  res.status(201).json(harvest);
});

app.get('/api/harvests', authMiddleware, (req, res) => {
  if (!db.harvests) db.harvests = [];
  const sid = req.user.storeId;
  let list = sid ? db.harvests.filter(h => h.storeId === sid) : db.harvests;
  res.json(list);
});

// ════════════════════════════════════════════════════════════════════════════
// PROFIT / LOSS ANALYSIS PER POND & BATCH
// ════════════════════════════════════════════════════════════════════════════

app.get('/api/analysis/profit', authMiddleware, (req, res) => {
  const sid = req.user.storeId;
  if (!db.harvests) db.harvests = [];
  const batches = db.fishbatches.filter(b => b.storeId === sid);
  const result = batches.map(batch => {
    const sp = db.species.find(s => s._id === batch.speciesId);
    const pond = db.ponds.find(p => p._id === batch.pondId);

    // Revenue from harvests
    const harvests = (db.harvests || []).filter(h => h.fishBatchId === batch._id);
    const harvestRevenue = harvests.reduce((s, h) => s + (h.totalRevenue || 0), 0);

    // Revenue from sale orders (only if NOT already counted via harvest)
    const sales = db.saleorders.filter(o => o.fishBatchId === batch._id && o.status === 'completed');
    const saleRevenue = sales.reduce((s, o) => s + (o.totalAmount || 0), 0);

    // Use the higher of harvest vs sale revenue to avoid double-counting
    const totalRevenue = Math.max(harvestRevenue, saleRevenue) || (harvestRevenue + saleRevenue);

    // Feed cost: use qty × costPrice for accurate cost tracking
    const feedIssues = db.stockissues.filter(i =>
      (i.pondId === batch.pondId || i.fishBatchId === batch._id) &&
      (i.type === 'usage' || i.type === 'feeding') && i.status === 'approved'
    );
    let feedCost = 0;
    for (const issue of feedIssues) {
      for (const it of (issue.items || [])) {
        const prod = db.products.find(p => p._id === it.productId);
        const unitCost = (prod && prod.costPrice > 0) ? prod.costPrice : (it.unitPrice || 0);
        feedCost += (it.qty || 0) * unitCost;
      }
    }

    // Seed cost: from batch import price
    const seedCost = (batch.initialQuantity || 0) * (batch.importPrice || 0);

    // Other costs
    const otherCosts = (db.othercosts || []).filter(c => c.fishBatchId === batch._id || c.pondId === batch.pondId);
    const otherCostTotal = otherCosts.reduce((s, c) => s + (c.amount || 0), 0);

    const totalCost = feedCost + otherCostTotal + seedCost;
    const profit = totalRevenue - totalCost;

    return {
      batchId: batch._id,
      pondId: batch.pondId,
      pondCode: pond?.code || '',
      speciesName: sp?.name || '',
      stockingDate: batch.stockingDate,
      initialQuantity: batch.initialQuantity,
      currentQuantity: batch.currentQuantity,
      mortalityQuantity: batch.mortalityQuantity,
      feedConsumed: batch.feedConsumed,
      status: batch.status,
      totalRevenue,
      feedCost,
      seedCost,
      otherCost: otherCostTotal,
      totalCost,
      profit,
      harvestCount: harvests.length,
    };
  });
  res.json(result);
});

// ════════════════════════════════════════════════════════════════════════════
// SUPPLIER DEBT TRACKING
// ════════════════════════════════════════════════════════════════════════════

app.get('/api/suppliers/debts', authMiddleware, (req, res) => {
  const sid = req.user.storeId;
  const suppliers = db.suppliers.filter(s => s.storeId === sid);
  const result = suppliers.map(sup => {
    // Total purchases
    const pos = db.purchaseorders.filter(po => po.supplierId === sup._id && po.status === 'completed');
    const totalPurchase = pos.reduce((s, po) => s + (po.total || 0), 0);

    // Total payments to supplier
    const payments = db.paymentvouchers.filter(pv =>
      pv.contactId === sup._id && pv.contactType === 'supplier' && pv.type === 'payment' && pv.status === 'confirmed'
    );
    const totalPaid = payments.reduce((s, pv) => s + (pv.amount || 0), 0);

    const debt = totalPurchase - totalPaid;
    // Also update supplier debt field
    sup.debt = debt;

    return {
      supplierId: sup._id,
      name: sup.name,
      phone: sup.phone,
      totalPurchase,
      totalPaid,
      debt,
      orderCount: pos.length,
    };
  });
  res.json(result);
});

// ════════════════════════════════════════════════════════════════════════════
// GLOBAL SEARCH
// ════════════════════════════════════════════════════════════════════════════

app.get('/api/search', authMiddleware, (req, res) => {
  const q = (req.query.q || '').toLowerCase().trim();
  if (!q || q.length < 2) return res.json([]);
  const sid = req.user.storeId;
  const results = [];
  const limit = 30;

  function match(obj, fields) {
    return fields.some(f => {
      const v = obj[f];
      return v && String(v).toLowerCase().includes(q);
    });
  }

  // Search ponds
  db.ponds.filter(p => (!sid || p.storeId === sid) && match(p, ['code', '_id'])).slice(0, 5)
    .forEach(p => results.push({ type: 'pond', id: p._id, title: `Ao ${p.code}`, subtitle: `${p.status} - ${p.area}m²` }));

  // Search fish batches
  db.fishbatches.filter(b => (!sid || b.storeId === sid) && match(b, ['_id', 'source', 'note'])).slice(0, 5)
    .forEach(b => { const sp = db.species.find(s => s._id === b.speciesId); results.push({ type: 'fishbatch', id: b._id, title: sp?.name || 'Lô cá', subtitle: `SL: ${b.currentQuantity}` }); });

  // Search employees
  db.employees.filter(e => (!sid || e.storeId === sid) && match(e, ['name', 'email', 'phone'])).slice(0, 5)
    .forEach(e => results.push({ type: 'employee', id: e._id, title: e.name, subtitle: e.role }));

  // Search customers
  db.customers.filter(c => (!sid || c.storeId === sid) && match(c, ['name', 'contact', 'address'])).slice(0, 5)
    .forEach(c => results.push({ type: 'customer', id: c._id, title: c.name, subtitle: c.address }));

  // Search suppliers
  db.suppliers.filter(s => (!sid || s.storeId === sid) && match(s, ['name', 'phone', 'email'])).slice(0, 5)
    .forEach(s => results.push({ type: 'supplier', id: s._id, title: s.name, subtitle: s.phone }));

  // Search products
  db.products.filter(p => (!sid || p.storeId === sid) && match(p, ['name', 'sku'])).slice(0, 5)
    .forEach(p => results.push({ type: 'product', id: p._id, title: p.name, subtitle: `${p.stock} ${p.unit}` }));

  // Search tasks
  db.tasks.filter(t => (!sid || t.storeId === sid) && match(t, ['title', 'note'])).slice(0, 5)
    .forEach(t => results.push({ type: 'task', id: t._id, title: t.title, subtitle: t.status }));

  // Search sale orders
  db.saleorders.filter(o => (!sid || o.storeId === sid) && match(o, ['_id'])).slice(0, 3)
    .forEach(o => results.push({ type: 'saleorder', id: o._id, title: `Đơn bán #${o._id.slice(0,8)}`, subtitle: `${(o.totalAmount || 0).toLocaleString('vi-VN')}đ` }));

  // Search purchase orders
  db.purchaseorders.filter(o => (!sid || o.storeId === sid) && match(o, ['code', 'supplier'])).slice(0, 3)
    .forEach(o => results.push({ type: 'purchaseorder', id: o._id, title: o.code, subtitle: o.supplier }));

  res.json(results.slice(0, limit));
});

// ════════════════════════════════════════════════════════════════════════════
// PROFILE UPDATE
// ════════════════════════════════════════════════════════════════════════════

app.put('/api/profile', authMiddleware, async (req, res) => {
  const { displayName, phone, address, storeName } = req.body;
  const emp = db.employees.find(e => e._id === req.user.id);
  if (!emp) return res.status(404).json({ message: 'Không tìm thấy tài khoản' });
  if (displayName) emp.name = displayName;
  if (phone !== undefined) emp.phone = phone;
  if (address !== undefined) emp.address = address;
  if (storeName !== undefined) emp.storeName = storeName;
  saveDb();
  res.json({ id: emp._id, email: emp.email, displayName: emp.name, storeName: emp.storeName, phone: emp.phone, address: emp.address, storeId: emp.storeId, role: emp.role, permissions: emp.permissions || [] });
});

app.put('/api/profile/password', authMiddleware, async (req, res) => {
  const { currentPassword, newPassword } = req.body;
  if (!currentPassword || !newPassword) return res.status(400).json({ message: 'Thiếu thông tin' });
  if (newPassword.length < 6) return res.status(400).json({ message: 'Mật khẩu mới phải có ít nhất 6 ký tự' });
  const emp = db.employees.find(e => e._id === req.user.id);
  if (!emp) return res.status(404).json({ message: 'Không tìm thấy tài khoản' });
  const valid = await bcrypt.compare(currentPassword, emp.password);
  if (!valid) return res.status(401).json({ message: 'Mật khẩu hiện tại không đúng' });
  emp.password = await bcrypt.hash(newPassword, 10);
  saveDb();
  res.json({ message: 'Đổi mật khẩu thành công' });
});

// ════════════════════════════════════════════════════════════════════════════
// FEEDING LOG
// ════════════════════════════════════════════════════════════════════════════

app.get('/api/feedinglogs', authMiddleware, (req, res) => {
  if (!db.feedinglogs) db.feedinglogs = [];
  const sid = req.user.storeId;
  let list = sid ? db.feedinglogs.filter(f => f.storeId === sid) : db.feedinglogs;
  res.json(list);
});

app.post('/api/feedinglogs', authMiddleware, (req, res) => {
  if (!db.feedinglogs) db.feedinglogs = [];
  const { pondId, fishBatchId, productId, quantity, date, note } = req.body;
  if (!pondId || !quantity) return res.status(400).json({ message: 'Thiếu thông tin' });
  if (quantity <= 0) return res.status(400).json({ message: 'Số lượng phải > 0' });

  const prod = productId ? db.products.find(p => p._id === productId) : null;

  const log = {
    _id: genId(),
    pondId,
    fishBatchId: fishBatchId || '',
    productId: productId || '',
    productName: prod?.name || req.body.productName || '',
    quantity,
    unit: prod?.unit || 'kg',
    date: date || new Date().toISOString(),
    note: note || '',
    storeId: req.user.storeId,
    createdBy: req.user.id,
    createdAt: new Date().toISOString(),
  };
  db.feedinglogs.push(log);

  // Update batch feedConsumed
  if (fishBatchId) {
    const batch = db.fishbatches.find(b => b._id === fishBatchId);
    if (batch) {
      batch.feedConsumed = (batch.feedConsumed || 0) + quantity;
      batch.updatedAt = new Date().toISOString();
    }
  }

  // Decrease product stock
  if (prod) {
    prod.stock = Math.max(0, (prod.stock || 0) - quantity);
  }

  saveDb();
  res.status(201).json(log);
});

// ════════════════════════════════════════════════════════════════════════════
// MORTALITY LOG
// ════════════════════════════════════════════════════════════════════════════

app.get('/api/mortalitylogs', authMiddleware, (req, res) => {
  if (!db.mortalitylogs) db.mortalitylogs = [];
  const sid = req.user.storeId;
  let list = sid ? db.mortalitylogs.filter(m => m.storeId === sid) : db.mortalitylogs;
  res.json(list);
});

app.post('/api/mortalitylogs', authMiddleware, (req, res) => {
  if (!db.mortalitylogs) db.mortalitylogs = [];
  const { fishBatchId, pondId, quantity, cause, date, note } = req.body;
  if (!fishBatchId || !quantity) return res.status(400).json({ message: 'Thiếu thông tin' });
  if (quantity <= 0) return res.status(400).json({ message: 'Số lượng phải > 0' });

  const log = {
    _id: genId(),
    fishBatchId,
    pondId: pondId || '',
    quantity,
    cause: cause || 'unknown',
    date: date || new Date().toISOString(),
    note: note || '',
    storeId: req.user.storeId,
    createdBy: req.user.id,
    createdAt: new Date().toISOString(),
  };

  const batch = db.fishbatches.find(b => b._id === fishBatchId);
  if (batch) {
    // Validate quantity doesn't exceed current quantity
    if (quantity > (batch.currentQuantity || 0)) {
      return res.status(400).json({ message: `Số lượng hao hụt (${quantity}) vượt quá số lượng hiện có (${batch.currentQuantity})` });
    }
    if (!log.pondId) log.pondId = batch.pondId;
    batch.mortalityQuantity = (batch.mortalityQuantity || 0) + quantity;
    batch.currentQuantity = Math.max(0, (batch.currentQuantity || 0) - quantity);
    batch.updatedAt = new Date().toISOString();

    // Update pondAllocations if applicable
    if (log.pondId && batch.pondAllocations && batch.pondAllocations.length > 0) {
      const alloc = batch.pondAllocations.find(a => a.pondId === log.pondId);
      if (alloc) {
        alloc.quantity = Math.max(0, (alloc.quantity || 0) - quantity);
        if (alloc.quantity <= 0) {
          batch.pondAllocations = batch.pondAllocations.filter(a => a.pondId !== log.pondId);
        }
      }
    }
  }

  db.mortalitylogs.push(log);
  saveDb();
  res.status(201).json(log);
});

// ═══════════════════════════════════════════════════════════════════════════════
// TREATMENT LOG — auto-calculate safe harvest date on create/update
// ═══════════════════════════════════════════════════════════════════════════════
app.post('/api/treatmentlogs/calculate', authMiddleware, (req, res) => {
  const { startDate, durationDays = 1, withdrawalDays = 0 } = req.body;
  if (!startDate) return res.status(400).json({ message: 'startDate is required' });
  const end = new Date(new Date(startDate).getTime() + durationDays * 86400000);
  const safe = new Date(end.getTime() + withdrawalDays * 86400000);
  res.json({ endDate: end.toISOString(), safeHarvestDate: safe.toISOString() });
});

// ═══════════════════════════════════════════════════════════════════════════════
// FEEDING SCHEDULE — auto-calculate daily amount (supports per-pond)
// ═══════════════════════════════════════════════════════════════════════════════
app.post('/api/feedingschedules/calculate', authMiddleware, (req, res) => {
  const { fishBatchId, pondId, rationPercent = 3 } = req.body;
  if (!db.feedingschedules) db.feedingschedules = [];

  // If pondId given, calculate for ALL active batches in that pond
  if (pondId) {
    const batches = (db.fishbatches || []).filter(b => b.status === 'active');
    let totalBiomass = 0;
    for (const batch of batches) {
      let qtyInPond = 0;
      if (batch.pondAllocations && batch.pondAllocations.length > 0) {
        const alloc = batch.pondAllocations.find(a => a.pondId === pondId);
        qtyInPond = alloc ? (alloc.quantity || 0) : 0;
      } else if (batch.pondId === pondId) {
        qtyInPond = batch.currentQuantity || 0;
      }
      if (qtyInPond > 0) {
        const weight = (batch.currentWeight || batch.initialWeight || 0);
        totalBiomass += qtyInPond * weight / 1000;
      }
    }
    const dailyAmount = totalBiomass * rationPercent / 100;
    return res.json({ totalBiomassKg: Math.round(totalBiomass * 100) / 100, dailyAmountKg: Math.round(dailyAmount * 100) / 100, rationPercent });
  }

  // Fallback: calculate for a specific batch
  const batch = (db.fishbatches || []).find(b => b._id === fishBatchId);
  if (!batch) return res.status(404).json({ message: 'Batch not found' });
  const totalBiomass = (batch.currentQuantity || 0) * (batch.currentWeight || 0) / 1000;
  const dailyAmount = totalBiomass * rationPercent / 100;
  res.json({ totalBiomassKg: Math.round(totalBiomass * 100) / 100, dailyAmountKg: Math.round(dailyAmount * 100) / 100, rationPercent });
});

// ═══════════════════════════════════════════════════════════════════════════════
// CROP CYCLE — aggregate costs/revenue
// ═══════════════════════════════════════════════════════════════════════════════
app.get('/api/cropcycles/:id/summary', authMiddleware, (req, res) => {
  if (!db.cropcycles) db.cropcycles = [];
  const cycle = db.cropcycles.find(c => c._id === req.params.id);
  if (!cycle) return res.status(404).json({ message: 'Crop cycle not found' });

  const batchIds = cycle.fishBatchIds || [];
  const batches = (db.fishbatches || []).filter(b => batchIds.includes(b._id));

  // Revenue from harvests
  const harvestRevenue = (db.harvests || [])
    .filter(h => batchIds.includes(h.fishBatchId))
    .reduce((s, h) => s + (h.totalRevenue || 0), 0);

  // Feed cost
  const feedCost = (db.feedinglogs || [])
    .filter(f => batchIds.includes(f.fishBatchId))
    .reduce((s, f) => {
      const product = (db.products || []).find(p => p._id === f.productId);
      return s + ((f.quantity || 0) * (product?.costPrice || 0));
    }, 0);

  // Seed cost
  const seedCost = batches.reduce((s, b) => s + ((b.initialQuantity || 0) * (b.importPrice || 0)), 0);

  // Other costs
  const otherCost = (db.othercosts || [])
    .filter(c => batchIds.includes(c.fishBatchId) || (cycle.pondIds || []).includes(c.pondId))
    .reduce((s, c) => s + (c.amount || 0), 0);

  // Treatment cost
  const treatmentCost = (db.treatmentlogs || [])
    .filter(t => batchIds.includes(t.fishBatchId) || (cycle.pondIds || []).includes(t.pondId))
    .reduce((s, t) => s + (t.cost || 0), 0);

  const totalCost = feedCost + seedCost + otherCost + treatmentCost;

  res.json({
    revenue: harvestRevenue,
    feedCost, seedCost, otherCost, treatmentCost, totalCost,
    profit: harvestRevenue - totalCost,
    totalBatches: batches.length,
    totalPonds: (cycle.pondIds || []).length,
  });
});

// ═══════════════════════════════════════════════════════════════════════════════
// EQUIPMENT — maintenance due notifications
// ═══════════════════════════════════════════════════════════════════════════════
app.get('/api/equipment/maintenance-due', authMiddleware, (req, res) => {
  if (!db.equipment) db.equipment = [];
  const now = new Date();
  const due = db.equipment
    .filter(e => e.storeId === req.user.storeId && e.status === 'active' && e.nextMaintenanceDate)
    .filter(e => new Date(e.nextMaintenanceDate) <= now);
  res.json(due);
});

// ═══════════════════════════════════════════════════════════════════════════════
// ENHANCED NOTIFICATIONS — merged into /notifications/check
// ═══════════════════════════════════════════════════════════════════════════════
// Kept as alias for backward compatibility
app.post('/api/notifications/check-extended', authMiddleware, (req, res) => {
  // Redirect to unified check endpoint
  const storeId = req.user.storeId;
  res.json({ created: 0, total: db.notifications.filter(n => (!storeId || n.storeId === storeId) && !n.read).length, message: 'Use /notifications/check instead' });
});

// ── Factory Reset ──
app.post('/api/factory-reset', authMiddleware, (req, res) => {
  if (req.user.role !== 'owner') {
    return res.status(403).json({ message: 'Chỉ chủ trại mới được khôi phục cài đặt gốc' });
  }
  const currentUser = db.employees.find(e => e._id === req.user.id);
  if (!currentUser) return res.status(404).json({ message: 'Không tìm thấy tài khoản' });

  // Reset all collections
  for (const key of Object.keys(db)) {
    if (Array.isArray(db[key])) {
      db[key] = [];
    } else {
      db[key] = {};
    }
  }
  // Keep only the current owner account
  db.employees = [currentUser];
  saveDb();
  res.json({ message: 'Đã khôi phục cài đặt gốc thành công' });
});

// ══════════════════════════════════════════════════════════════
// ── SYSADMIN ROUTES (Platform Admin) ──
// ══════════════════════════════════════════════════════════════

// Seed default sysadmin on first boot
async function seedSysadmin() {
  if (db.sysadmins.length === 0) {
    const hashed = await bcrypt.hash('123456a@', 10);
    db.sysadmins.push({
      _id: genId(),
      email: 'sanapos.vn@gmail.com',
      password: hashed,
      name: 'System Admin',
      role: 'sysadmin',
      createdAt: new Date().toISOString(),
    });
    saveDb();
    console.log('Seeded default sysadmin account');
  }
}

function sysadminMiddleware(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ message: 'Chưa đăng nhập' });
  }
  try {
    const token = authHeader.split(' ')[1];
    const decoded = jwt.verify(token, JWT_SECRET);
    if (decoded.role !== 'sysadmin') {
      return res.status(403).json({ message: 'Không có quyền truy cập' });
    }
    const admin = db.sysadmins.find(a => a._id === decoded.id);
    if (!admin) return res.status(401).json({ message: 'Tài khoản không tồn tại' });
    req.admin = { id: admin._id, role: 'sysadmin' };
    next();
  } catch (err) {
    return res.status(401).json({ message: 'Token không hợp lệ hoặc đã hết hạn' });
  }
}

// Sysadmin Login
app.post('/api/sysadmin/login', async (req, res) => {
  const { email, password } = req.body;
  if (!email || !password) return res.status(400).json({ message: 'Vui lòng nhập email và mật khẩu' });
  const admin = db.sysadmins.find(a => a.email === email);
  if (!admin) return res.status(404).json({ message: 'Tài khoản không tồn tại' });
  const valid = await bcrypt.compare(password, admin.password);
  if (!valid) return res.status(401).json({ message: 'Mật khẩu không đúng' });
  const token = jwt.sign({ id: admin._id, role: 'sysadmin' }, JWT_SECRET, { expiresIn: '7d' });
  res.json({ id: admin._id, email: admin.email, name: admin.name, role: 'sysadmin', token });
});

// Dashboard stats
app.get('/api/sysadmin/dashboard', sysadminMiddleware, (req, res) => {
  const stores = db.branches.map(b => {
    const storeEmployees = db.employees.filter(e => e.storeId === (b.storeId || b._id));
    const owner = storeEmployees.find(e => e.role === 'owner');
    return { ...b, storeId: b.storeId || b._id, ownerEmail: owner?.email || '', ownerName: owner?.name || '' };
  });
  // Deduplicate stores by storeId (first branch per storeId represents the store)
  const storeMap = new Map();
  stores.forEach(s => { if (!storeMap.has(s.storeId)) storeMap.set(s.storeId, s); });
  const uniqueStores = [...storeMap.values()];

  const totalStores = uniqueStores.length;
  const totalEmployees = db.employees.length;
  const totalPonds = db.ponds.length;
  const totalBatches = db.fishbatches.length;
  const activeLicenses = db.licenses.filter(l => l.status === 'active' && new Date(l.expiresAt) > new Date()).length;
  const expiredLicenses = db.licenses.filter(l => l.status === 'active' && new Date(l.expiresAt) <= new Date()).length;

  // Recent stores (last 10)
  const recentStores = uniqueStores
    .sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt))
    .slice(0, 10)
    .map(s => ({
      _id: s.storeId,
      name: s.name,
      ownerEmail: s.ownerEmail,
      ownerName: s.ownerName,
      createdAt: s.createdAt,
      status: s.status || 'active',
    }));

  res.json({
    totalStores,
    totalEmployees,
    totalPonds,
    totalBatches,
    activeLicenses,
    expiredLicenses,
    recentStores,
  });
});

// List all stores
app.get('/api/sysadmin/stores', sysadminMiddleware, (req, res) => {
  const storeMap = new Map();
  db.branches.forEach(b => {
    const sid = b.storeId || b._id;
    if (!storeMap.has(sid)) storeMap.set(sid, { ...b, storeId: sid });
  });

  const stores = [...storeMap.values()].map(store => {
    const storeEmployees = db.employees.filter(e => e.storeId === store.storeId);
    const owner = storeEmployees.find(e => e.role === 'owner');
    const branches = db.branches.filter(b => (b.storeId || b._id) === store.storeId);
    const ponds = db.ponds.filter(p => p.storeId === store.storeId);
    const license = db.licenses.find(l => l.storeId === store.storeId && l.status === 'active');

    return {
      _id: store.storeId,
      name: store.name,
      address: store.address || '',
      contact: store.contact || '',
      ownerName: owner?.name || '',
      ownerEmail: owner?.email || '',
      ownerPhone: owner?.phone || '',
      employeeCount: storeEmployees.length,
      branchCount: branches.length,
      pondCount: ponds.length,
      status: store.status || 'active',
      license: license ? {
        key: license.key,
        plan: license.plan,
        expiresAt: license.expiresAt,
      } : null,
      createdAt: store.createdAt,
    };
  });

  stores.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
  res.json(stores);
});

// Get store detail
app.get('/api/sysadmin/stores/:id', sysadminMiddleware, (req, res) => {
  const storeId = req.params.id;
  const branches = db.branches.filter(b => (b.storeId || b._id) === storeId);
  if (branches.length === 0) return res.status(404).json({ message: 'Cửa hàng không tồn tại' });

  const employees = db.employees.filter(e => e.storeId === storeId).map(e => ({
    _id: e._id, name: e.name, email: e.email, phone: e.phone, role: e.role, hasAccount: e.hasAccount, createdAt: e.createdAt,
  }));
  const ponds = db.ponds.filter(p => p.storeId === storeId);
  const zones = db.zones.filter(z => z.storeId === storeId);
  const batches = db.fishbatches.filter(f => f.storeId === storeId);
  const licenses = db.licenses.filter(l => l.storeId === storeId);
  const owner = employees.find(e => e.role === 'owner');

  res.json({
    _id: storeId,
    name: branches[0].name,
    address: branches[0].address || '',
    contact: branches[0].contact || '',
    status: branches[0].status || 'active',
    ownerName: owner?.name || '',
    ownerEmail: owner?.email || '',
    createdAt: branches[0].createdAt,
    branches: branches.map(b => ({ _id: b._id, name: b.name, address: b.address })),
    employees,
    pondCount: ponds.length,
    zoneCount: zones.length,
    batchCount: batches.length,
    licenses,
  });
});

// Toggle store status (active/suspended)
app.put('/api/sysadmin/stores/:id/status', sysadminMiddleware, (req, res) => {
  const storeId = req.params.id;
  const { status } = req.body; // 'active' or 'suspended'
  if (!['active', 'suspended'].includes(status)) {
    return res.status(400).json({ message: 'Trạng thái không hợp lệ' });
  }
  const branches = db.branches.filter(b => (b.storeId || b._id) === storeId);
  if (branches.length === 0) return res.status(404).json({ message: 'Cửa hàng không tồn tại' });
  branches.forEach(b => b.status = status);
  saveDb();
  res.json({ message: `Đã ${status === 'active' ? 'kích hoạt' : 'tạm ngưng'} cửa hàng`, status });
});

// ── License Management ──
app.get('/api/sysadmin/licenses', sysadminMiddleware, (req, res) => {
  const licenses = db.licenses.map(l => {
    const store = db.branches.find(b => (b.storeId || b._id) === l.storeId);
    return { ...l, storeName: store?.name || 'N/A' };
  });
  licenses.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
  res.json(licenses);
});

app.post('/api/sysadmin/licenses', sysadminMiddleware, (req, res) => {
  const { storeId, plan, durationDays, note } = req.body;
  if (!storeId || !plan || !durationDays) {
    return res.status(400).json({ message: 'Thiếu thông tin bắt buộc' });
  }
  const store = db.branches.find(b => (b.storeId || b._id) === storeId);
  if (!store) return res.status(404).json({ message: 'Cửa hàng không tồn tại' });

  // Deactivate existing active licenses for this store
  db.licenses.filter(l => l.storeId === storeId && l.status === 'active').forEach(l => l.status = 'replaced');

  const now = new Date();
  const expiresAt = new Date(now.getTime() + parseInt(durationDays) * 24 * 60 * 60 * 1000);
  const key = 'AQ-' + crypto.randomUUID().replace(/-/g, '').substring(0, 16).toUpperCase();

  const license = {
    _id: genId(),
    key,
    storeId,
    plan,  // 'trial', 'basic', 'pro', 'enterprise'
    durationDays: parseInt(durationDays),
    status: 'active',
    note: note || '',
    createdAt: now.toISOString(),
    expiresAt: expiresAt.toISOString(),
  };
  db.licenses.push(license);
  // Also activate the store
  db.branches.filter(b => (b.storeId || b._id) === storeId).forEach(b => b.status = 'active');
  saveDb();
  res.status(201).json(license);
});

app.put('/api/sysadmin/licenses/:id', sysadminMiddleware, (req, res) => {
  const license = db.licenses.find(l => l._id === req.params.id);
  if (!license) return res.status(404).json({ message: 'License không tồn tại' });
  const { status, note } = req.body;
  if (status) license.status = status;
  if (note !== undefined) license.note = note;
  saveDb();
  res.json(license);
});

app.delete('/api/sysadmin/licenses/:id', sysadminMiddleware, (req, res) => {
  const idx = db.licenses.findIndex(l => l._id === req.params.id);
  if (idx === -1) return res.status(404).json({ message: 'License không tồn tại' });
  db.licenses.splice(idx, 1);
  saveDb();
  res.json({ message: 'Đã xóa license' });
});

// Sysadmin change password
app.put('/api/sysadmin/password', sysadminMiddleware, async (req, res) => {
  const { currentPassword, newPassword } = req.body;
  if (!currentPassword || !newPassword) return res.status(400).json({ message: 'Thiếu thông tin' });
  if (newPassword.length < 6) return res.status(400).json({ message: 'Mật khẩu mới phải có ít nhất 6 ký tự' });
  const admin = db.sysadmins.find(a => a._id === req.admin.id);
  if (!admin) return res.status(404).json({ message: 'Tài khoản không tồn tại' });
  const valid = await bcrypt.compare(currentPassword, admin.password);
  if (!valid) return res.status(401).json({ message: 'Mật khẩu hiện tại không đúng' });
  admin.password = await bcrypt.hash(newPassword, 10);
  saveDb();
  res.json({ message: 'Đổi mật khẩu thành công' });
});

// ── Load persisted DB or use seed data ──
const savedDb = loadDb();
if (savedDb) {
  for (const key of Object.keys(savedDb)) {
    db[key] = savedDb[key];
  }
  // Ensure new collections exist in old data
  if (!db.sysadmins) db.sysadmins = [];
  if (!db.licenses) db.licenses = [];
  console.log('Loaded data from', DB_FILE);
}

const PORT = process.env.PORT || 3000;
app.listen(PORT, async () => {
  await seedSysadmin();
  saveDb(); // Initial save
  console.log(`Server running on port ${PORT} (persistent file mode: ${DB_FILE})`);
});