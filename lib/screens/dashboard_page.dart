import 'package:flutter/material.dart';

import '../services/dashboard_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  DateTime fromDate = DateTime.now();
  DateTime toDate = DateTime.now();

  String filterType = 'Date';

  DashboardSummary? summary;
  bool loading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day-$month-${date.year}';
  }

  Future<void> _loadDashboard() async {
    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final result = await DashboardService.instance.calculate(
        from: fromDate,
        to: DateTime(
          toDate.year,
          toDate.month,
          toDate.day,
          23,
          59,
          59,
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        summary = result;
        loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        loading = false;
        errorMessage = error.toString();
      });
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: fromDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked == null) {
      return;
    }

    setState(() {
      fromDate = picked;
      toDate = picked;
    });

    await _loadDashboard();
  }

  Future<void> _selectDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(
        start: fromDate,
        end: toDate,
      ),
    );

    if (range == null) {
      return;
    }

    setState(() {
      fromDate = range.start;
      toDate = range.end;
    });

    await _loadDashboard();
  }

  Future<void> _selectMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: fromDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDatePickerMode: DatePickerMode.year,
    );

    if (picked == null) {
      return;
    }

    final start = DateTime(
      picked.year,
      picked.month,
      1,
    );

    final end = DateTime(
      picked.year,
      picked.month + 1,
      0,
    );

    setState(() {
      fromDate = start;
      toDate = end;
    });

    await _loadDashboard();
  }

  String _periodText() {
    if (filterType == 'Date') {
      return _formatDate(fromDate);
    }

    if (filterType == 'Month') {
      return '${_monthName(fromDate.month)} ${fromDate.year}';
    }

    return '${_formatDate(fromDate)} to ${_formatDate(toDate)}';
  }

  String _monthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return months[month - 1];
  }

  Future<void> _changeFilter(String value) async {
    setState(() {
      filterType = value;
    });

    if (value == 'Date') {
      await _selectDate();
    } else if (value == 'Date Range') {
      await _selectDateRange();
    } else {
      await _selectMonth();
    }
  }

  String _money(double value) {
    return '₹${value.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final data = summary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: loading ? null : _loadDashboard,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboard,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(7),
          children: [
            _buildFilterCard(context),
            const SizedBox(height: 12),

            if (loading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (errorMessage != null)
              _buildErrorCard(context)
            else if (data != null)
              _buildDashboardContent(context, data)
            else
              _buildEmptyCard(context),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dashboard Period',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: filterType,
              items: const [
                DropdownMenuItem(
                  value: 'Date',
                  child: Text('Date-wise'),
                ),
                DropdownMenuItem(
                  value: 'Date Range',
                  child: Text('Date Range-wise'),
                ),
                DropdownMenuItem(
                  value: 'Month',
                  child: Text('Month-wise'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  _changeFilter(value);
                }
              },
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.filter_alt_outlined),
                labelText: 'Filter',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () {
                if (filterType == 'Date') {
                  _selectDate();
                } else if (filterType == 'Date Range') {
                  _selectDateRange();
                } else {
                  _selectMonth();
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: InputDecorator(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.calendar_month),
                  labelText: 'Selected Period',
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  _periodText(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardContent(
    BuildContext context,
    DashboardSummary data,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Business Overview',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 10),

        _metricGrid(
          context,
          [
            _MetricData(
              'Sales',
              _money(data.sales),
              Icons.point_of_sale_outlined,
            ),
            _MetricData(
              'Payments Received',
              _money(data.paymentsReceived),
              Icons.payments_outlined,
            ),
            _MetricData(
              'Outstanding',
              _money(data.outstanding),
              Icons.account_balance_wallet_outlined,
            ),
            _MetricData(
              'Commission',
              _money(data.commission),
              Icons.percent_outlined,
            ),
          ],
        ),

        const SizedBox(height: 16),

        Text(
          'Production & Expenses',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 10),

        _metricGrid(
          context,
          [
            _MetricData(
              'Production',
              '${data.productionBoxes.toStringAsFixed(0)} Boxes',
              Icons.factory_outlined,
            ),
            _MetricData(
              'Expenses',
              _money(data.expenses),
              Icons.receipt_long_outlined,
            ),
            _MetricData(
              'Salary',
              _money(data.salary),
              Icons.people_outline,
            ),
            _MetricData(
              'Profit / Loss',
              _money(data.profitLoss),
              data.profitLoss >= 0
                  ? Icons.trending_up
                  : Icons.trending_down,
            ),
          ],
        ),

        const SizedBox(height: 16),

        Text(
          'Capital',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 10),

        _metricGrid(
          context,
          [
            _MetricData(
              'Capital Received',
              _money(data.capitalReceived),
              Icons.arrow_downward,
            ),
            _MetricData(
              'Capital Returned',
              _money(data.capitalReturned),
              Icons.arrow_upward,
            ),
            _MetricData(
              'Capital Balance',
              _money(
                data.capitalReceived - data.capitalReturned,
              ),
              Icons.account_balance_outlined,
            ),
          ],
        ),

        const SizedBox(height: 18),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'Profit / Loss Summary',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 14),
                _summaryRow(
                  'Total Sales',
                  _money(data.sales),
                ),
                _summaryRow(
                  'Commission',
                  _money(data.commission),
                ),
                _summaryRow(
                  'Expenses',
                  _money(data.expenses),
                ),
                _summaryRow(
                  'Salary',
                  _money(data.salary),
                ),
                const Divider(height: 20),
                _summaryRow(
                  data.profitLoss >= 0
                      ? 'Net Profit'
                      : 'Net Loss',
                  _money(data.profitLoss),
                  bold: true,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        Card(
          child: ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.insights_outlined),
            ),
            title: const Text(
              'Outstanding Balance',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: const Text(
              'Net amount still to be collected from business transactions',
            ),
            trailing: Text(
              _money(data.outstanding),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _metricGrid(
    BuildContext context,
    List<_MetricData> metrics,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 700 ? 4 : 2;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: metrics.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: columns == 4 ? 1.65 : 1.55,
          ),
          itemBuilder: (context, index) {
            final metric = metrics[index];

            return Card(
              elevation: 1.5,
              margin: EdgeInsets.zero,
              color: colorScheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(7),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      metric.icon,
                      size: 20,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      metric.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        metric.value,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _summaryRow(
    String title,
    String value, {
    bool bold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 5,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight:
                    bold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight:
                  bold ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
            ),
            const SizedBox(height: 10),
            const Text(
              'Unable to load dashboard',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage ?? 'Unknown error',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _loadDashboard,
              icon: const Icon(Icons.refresh),
              label: const Text('RETRY'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCard(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(30),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.dashboard_outlined,
                size: 52,
              ),
              SizedBox(height: 12),
              Text(
                'No dashboard data',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricData {
  final String title;
  final String value;
  final IconData icon;

  const _MetricData(
    this.title,
    this.value,
    this.icon,
  );
}
