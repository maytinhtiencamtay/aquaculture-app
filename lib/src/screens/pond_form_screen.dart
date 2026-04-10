import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/pond.dart';
import '../providers/data_provider.dart';

class PondFormScreen extends StatefulWidget {
  const PondFormScreen({super.key});

  @override
  State<PondFormScreen> createState() => _PondFormScreenState();
}

class _PondFormScreenState extends State<PondFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _areaController = TextEditingController();
  final _volumeController = TextEditingController();
  String _type = 'earth';
  String _status = 'inactive';
  bool _isLoading = false;
  Pond? _editing;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final arg = ModalRoute.of(context)?.settings.arguments;
    if (arg is Pond && _editing == null) {
      _editing = arg;
      _codeController.text = arg.code;
      _areaController.text = arg.area.toString();
      _volumeController.text = arg.volume.toString();
      _type = arg.type;
      _status = arg.status;
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _areaController.dispose();
    _volumeController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final data = {
      'code': _codeController.text.trim(),
      'area': double.tryParse(_areaController.text) ?? 0,
      'volume': double.tryParse(_volumeController.text) ?? 0,
      'type': _type,
      'status': _status,
    };

    final provider = context.read<DataProvider>();
    bool ok;
    if (_editing != null) {
      ok = await provider.update('ponds', _editing!.id, data);
    } else {
      ok = await provider.create('ponds', data);
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_editing != null ? 'Cập nhật thành công' : 'Thêm ao thành công')),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Có lỗi xảy ra, vui lòng thử lại')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_editing != null ? 'Sửa ao ${_editing!.code}' : 'Thêm ao mới')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: 'Mã ao *',
                  hintText: 'VD: A1, B2...',
                  prefixIcon: Icon(Icons.label),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập mã ao' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _areaController,
                      decoration: const InputDecoration(
                        labelText: 'Diện tích (m²)',
                        prefixIcon: Icon(Icons.square_foot),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _volumeController,
                      decoration: const InputDecoration(
                        labelText: 'Thể tích (m³)',
                        prefixIcon: Icon(Icons.water),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _PondTypeAutocomplete(
                initialValue: _type,
                onChanged: (v) => setState(() => _type = v),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(
                  labelText: 'Trạng thái',
                  prefixIcon: Icon(Icons.flag),
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'active', child: Text('Đang nuôi')),
                  DropdownMenuItem(value: 'inactive', child: Text('Trống')),
                  DropdownMenuItem(value: 'maintenance', child: Text('Bảo trì')),
                  DropdownMenuItem(value: 'treatment', child: Text('Xử lý')),
                ],
                onChanged: (v) => setState(() => _status = v!),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _isLoading ? null : _save,
                icon: _isLoading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save),
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(_editing != null ? 'Cập nhật' : 'Thêm ao'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pond type combo: preset options + free text input
class _PondTypeAutocomplete extends StatefulWidget {
  final String initialValue;
  final ValueChanged<String> onChanged;
  const _PondTypeAutocomplete({required this.initialValue, required this.onChanged});
  @override
  State<_PondTypeAutocomplete> createState() => _PondTypeAutocompleteState();
}

class _PondTypeAutocompleteState extends State<_PondTypeAutocomplete> {
  static const _presets = <String, String>{
    'earth': 'Ao đất',
    'hdpe': 'Ao HDPE',
    'glass': 'Bể kính',
    'cage': 'Lồng',
  };

  late final TextEditingController _ctrl;
  late String _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
    _ctrl = TextEditingController(text: _presets[_value] ?? _value);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _toKey(String display) {
    final entry = _presets.entries.where((e) => e.value == display);
    return entry.isNotEmpty ? entry.first.key : display;
  }

  @override
  Widget build(BuildContext context) {
    final allOptions = _presets.values.toList();
    return Autocomplete<String>(
      optionsBuilder: (v) {
        if (v.text.isEmpty) return allOptions;
        return allOptions.where((o) => o.toLowerCase().contains(v.text.toLowerCase()));
      },
      fieldViewBuilder: (ctx, textCtrl, focusNode, onSubmitted) {
        if (textCtrl.text.isEmpty && _ctrl.text.isNotEmpty) {
          textCtrl.text = _ctrl.text;
        }
        return TextField(
          controller: textCtrl,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: 'Loại ao',
            prefixIcon: Icon(Icons.water),
            border: OutlineInputBorder(),
            hintText: 'Chọn hoặc nhập loại ao mới',
          ),
          onChanged: (v) {
            _value = _toKey(v);
            widget.onChanged(_value);
          },
          onSubmitted: (_) => onSubmitted(),
        );
      },
      onSelected: (v) {
        _value = _toKey(v);
        widget.onChanged(_value);
      },
    );
  }
}
