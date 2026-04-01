import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/data_provider.dart';
import '../../models/customer.dart';
import '../../theme/app_theme.dart';
import '../../widgets/paginated_list_view.dart';
import '../main_screen_helpers.dart';

// ═════════════════════════════════════════════════════════════════════════════
// CUSTOMER VIEW – extracted from main_screen.dart
// ═════════════════════════════════════════════════════════════════════════════

class CustomerView extends StatefulWidget {
  final DataProvider dp;
  final VoidCallback onCreate;
  final Function(Customer) onEdit;
  final Function(Customer) onDelete;
  const CustomerView({super.key, required this.dp, required this.onCreate, required this.onEdit, required this.onDelete});
  @override
  State<CustomerView> createState() => _CustomerViewState();
}

class _CustomerViewState extends State<CustomerView> {
  String _searchQuery = '';
  String _typeFilter = 'all';
  bool _debtOnly = false;
  String _sort = 'name_asc';

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DataProvider>();
    var customers = dp.customers.toList();

    final totalCustomers = dp.customers.length;
    final wholesaleCount = dp.customers.where((c) => c.type == 'wholesale').length;
    final retailCount = dp.customers.where((c) => c.type == 'retail').length;
    final totalDebt = dp.customers.fold<double>(0, (s, c) => s + c.debt);
    final debtCount = dp.customers.where((c) => c.debt > 0).length;

    if (_typeFilter != 'all') customers = customers.where((c) => c.type == _typeFilter).toList();
    if (_debtOnly) customers = customers.where((c) => c.debt > 0).toList();
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      customers = customers.where((c) =>
        c.name.toLowerCase().contains(q) ||
        c.phone.toLowerCase().contains(q) ||
        c.email.toLowerCase().contains(q) ||
        c.company.toLowerCase().contains(q) ||
        c.contact.toLowerCase().contains(q) ||
        c.address.toLowerCase().contains(q)
      ).toList();
    }

    switch (_sort) {
      case 'name_asc': customers.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())); break;
      case 'name_desc': customers.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase())); break;
      case 'debt_desc': customers.sort((a, b) => b.debt.compareTo(a.debt)); break;
      case 'newest': customers.sort((a, b) => b.createdAt.compareTo(a.createdAt)); break;
      case 'oldest': customers.sort((a, b) => a.createdAt.compareTo(b.createdAt)); break;
    }

    final hasFilter = _typeFilter != 'all' || _debtOnly || _searchQuery.isNotEmpty;

    return Column(
      children: [
        SectionHeader(title: 'Khách hàng (${customers.length})', onAdd: widget.onCreate),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              MiniStat('Tổng KH', '$totalCustomers', AppColors.primary),
              const SizedBox(width: 10),
              MiniStat('Đại lý', '$wholesaleCount', AppColors.info),
              const SizedBox(width: 10),
              MiniStat('Khách lẻ', '$retailCount', AppColors.secondary),
              const SizedBox(width: 10),
              MiniStat('Còn nợ', '$debtCount', AppColors.error),
            ],
          ),
        ),
        const SizedBox(height: 4),
        if (totalDebt > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.error.withAlpha(15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.error.withAlpha(40)),
              ),
              child: Row(children: [
                const Icon(Icons.account_balance_wallet_outlined, size: 18, color: AppColors.error),
                const SizedBox(width: 8),
                const Text('Tổng công nợ: ', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                Text('${currencyFmt.format(totalDebt)}đ', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.error)),
              ]),
            ),
          ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                SizedBox(
                  width: 200,
                  height: 34,
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Tìm tên, SĐT, công ty...',
                      hintStyle: const TextStyle(fontSize: 12),
                      prefixIcon: const Icon(Icons.search, size: 18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: AppColors.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: AppColors.border)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: AppColors.primary)),
                      filled: true,
                      fillColor: AppColors.surfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownFilter(
                  value: _typeFilter,
                  items: const {'all': 'Tất cả loại', 'wholesale': 'Đại lý', 'retail': 'Khách lẻ'},
                  onChanged: (v) => setState(() => _typeFilter = v),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => _debtOnly = !_debtOnly),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: _debtOnly ? AppColors.error : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _debtOnly ? AppColors.error : AppColors.border),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.money_off_rounded, size: 14, color: _debtOnly ? Colors.white : AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text('Còn nợ',
                          style: TextStyle(color: _debtOnly ? Colors.white : AppColors.textSecondary, fontWeight: _debtOnly ? FontWeight.w600 : FontWeight.w400, fontSize: 13)),
                    ]),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownFilter(
                  value: _sort,
                  items: const {'name_asc': 'Tên A→Z', 'name_desc': 'Tên Z→A', 'debt_desc': 'Nợ cao nhất', 'newest': 'Mới nhất', 'oldest': 'Cũ nhất'},
                  onChanged: (v) => setState(() => _sort = v),
                ),
                if (hasFilter) ...[
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(Icons.clear, size: 14),
                    label: const Text('Xoá lọc', style: TextStyle(fontSize: 12)),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() { _typeFilter = 'all'; _debtOnly = false; _searchQuery = ''; }),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: PaginatedListView<Customer>(
            items: customers,
            itemsPerPage: 20,
            emptyWidget: const EmptyState(icon: Icons.person_pin_rounded, message: 'Không tìm thấy khách hàng'),
            itemBuilder: (_, c, __) {
                final orderCount = dp.saleOrders.where((s) => s.customerId == c.id).length;
                final totalBought = dp.saleOrders.where((s) => s.customerId == c.id).fold<double>(0, (s, o) => s + o.totalAmount);
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _showCustomerDetail(context, dp, c),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: (c.type == 'wholesale' ? AppColors.primary : AppColors.secondary).withAlpha(20),
                                child: Icon(
                                  c.type == 'wholesale' ? Icons.store_rounded : Icons.person_rounded,
                                  color: c.type == 'wholesale' ? AppColors.primary : AppColors.secondary,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Flexible(child: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15), overflow: TextOverflow.ellipsis)),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: (c.type == 'wholesale' ? AppColors.info : AppColors.secondary).withAlpha(15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(c.typeLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: c.type == 'wholesale' ? AppColors.info : AppColors.secondary)),
                                    ),
                                  ]),
                                  if (c.company.isNotEmpty)
                                    Text(c.company, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                ],
                              )),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, size: 20),
                                onSelected: (v) {
                                  if (v == 'edit') widget.onEdit(c);
                                  if (v == 'delete') widget.onDelete(c);
                                },
                                itemBuilder: (ctx) => [
                                  const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit, size: 20), title: Text('Sửa'), dense: true, contentPadding: EdgeInsets.zero)),
                                  const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete, color: AppColors.error, size: 20), title: Text('Xoá', style: TextStyle(color: AppColors.error)), dense: true, contentPadding: EdgeInsets.zero)),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 14,
                            runSpacing: 4,
                            children: [
                              if (c.phone.isNotEmpty) _iconText(Icons.phone_rounded, c.phone),
                              if (c.email.isNotEmpty) _iconText(Icons.email_rounded, c.email),
                              if (c.address.isNotEmpty) _iconText(Icons.location_on_rounded, c.address),
                              if (c.contact.isNotEmpty) _iconText(Icons.contact_phone_rounded, c.contact),
                            ],
                          ),
                          const Divider(height: 16),
                          Row(
                            children: [
                              _miniTag(Icons.receipt_long_rounded, '$orderCount đơn', AppColors.primary),
                              const SizedBox(width: 8),
                              _miniTag(Icons.shopping_cart_rounded, '${currencyFmt.format(totalBought)}đ', AppColors.success),
                              const Spacer(),
                              if (c.debt > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.error.withAlpha(15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppColors.error.withAlpha(40)),
                                  ),
                                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    const Icon(Icons.warning_amber_rounded, size: 13, color: AppColors.error),
                                    const SizedBox(width: 4),
                                    Text('Nợ ${currencyFmt.format(c.debt)}đ', style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w700, fontSize: 12)),
                                  ]),
                                )
                              else
                                const StatusChip('Không nợ', AppColors.success),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _iconText(IconData icon, String text) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 13, color: AppColors.textHint),
    const SizedBox(width: 4),
    Text(text, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
  ]);

  Widget _miniTag(IconData icon, String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: color.withAlpha(12), borderRadius: BorderRadius.circular(6)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 4),
      Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    ]),
  );

  void _showCustomerDetail(BuildContext context, DataProvider dp, Customer c) {
    final orders = dp.saleOrders.where((s) => s.customerId == c.id).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final totalBought = orders.fold<double>(0, (s, o) => s + o.totalAmount);

    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Row(children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: (c.type == 'wholesale' ? AppColors.primary : AppColors.secondary).withAlpha(20),
            child: Icon(c.type == 'wholesale' ? Icons.store_rounded : Icons.person_rounded, size: 18,
              color: c.type == 'wholesale' ? AppColors.primary : AppColors.secondary),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.name, style: const TextStyle(fontSize: 16)),
            if (c.company.isNotEmpty) Text(c.company, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w400)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: (c.type == 'wholesale' ? AppColors.info : AppColors.secondary).withAlpha(15), borderRadius: BorderRadius.circular(6)),
            child: Text(c.typeLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.type == 'wholesale' ? AppColors.info : AppColors.secondary)),
          ),
        ]),
        content: SizedBox(
          width: 550,
          height: 400,
          child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(10)),
              child: Column(children: [
                if (c.phone.isNotEmpty) _detailRow(Icons.phone_rounded, 'Số điện thoại', c.phone),
                if (c.email.isNotEmpty) _detailRow(Icons.email_rounded, 'Email', c.email),
                if (c.address.isNotEmpty) _detailRow(Icons.location_on_rounded, 'Địa chỉ', c.address),
                if (c.contact.isNotEmpty) _detailRow(Icons.contact_phone_rounded, 'Người liên hệ', c.contact),
                _detailRow(Icons.calendar_today_rounded, 'Ngày tạo', DateFormat('dd/MM/yyyy').format(c.createdAt)),
                if (c.note.isNotEmpty) _detailRow(Icons.note_alt_rounded, 'Ghi chú', c.note),
              ]),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _statCard('Tổng đơn', '${orders.length}', AppColors.primary)),
              const SizedBox(width: 8),
              Expanded(child: _statCard('Doanh số', '${currencyFmt.format(totalBought)}đ', AppColors.success)),
              const SizedBox(width: 8),
              Expanded(child: _statCard('Công nợ', '${currencyFmt.format(c.debt)}đ', c.debt > 0 ? AppColors.error : AppColors.success)),
            ]),
            const SizedBox(height: 16),
            Text('Lịch sử đơn hàng (${orders.length})', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 8),
            if (orders.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                alignment: Alignment.center,
                child: const Text('Chưa có đơn hàng nào', style: TextStyle(color: AppColors.textHint, fontSize: 13)),
              )
            else
              ...orders.take(20).map((o) {
                final itemCount = o.items.length;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _orderStatusColor(o.status).withAlpha(15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.receipt_rounded, size: 18, color: _orderStatusColor(o.status)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(DateFormat('dd/MM/yyyy').format(o.date), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      Text('$itemCount sản phẩm • ${o.statusLabel}', style: TextStyle(fontSize: 12, color: _orderStatusColor(o.status))),
                    ])),
                    Text('${currencyFmt.format(o.totalAmount)}đ', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.primary)),
                  ]),
                );
              }),
          ])),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Đóng')),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Icon(icon, size: 16, color: AppColors.textHint),
      const SizedBox(width: 8),
      SizedBox(width: 100, child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
    ]),
  );

  Widget _statCard(String label, String value, Color color) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
    decoration: BoxDecoration(color: color.withAlpha(12), borderRadius: BorderRadius.circular(10)),
    child: Column(children: [
      Text(value, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: color)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
    ]),
  );

  Color _orderStatusColor(String status) {
    switch (status) {
      case 'completed': return AppColors.success;
      case 'cancelled': return AppColors.error;
      default: return AppColors.warning;
    }
  }
}
