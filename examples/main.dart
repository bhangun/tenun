import 'package:flutter/material.dart';
import 'package:tenun_core/core/chart_type.dart';
import 'package:tenun_core/widget/tenun_widget.dart';

class MyDashboard extends StatefulWidget {
  const MyDashboard({super.key});

  @override
  State<MyDashboard> createState() => _MyDashboardState();
}

class _MyDashboardState extends State<MyDashboard> {
  final Map<String, dynamic> _salesJson = {
    "type": "bar",
    "title": {
      "text": "Monthly Sales Report",
      "fontSize": 18,
      "fontWeight": "bold",
    },
    "tooltip": {"show": true, "formatter": "{a}: {c} units"},
    "legend": {
      "show": true,
      "data": ["Revenue", "Profit"],
    },
    "grid": {"show": true, "showHorizontalLines": true},
    "xAxis": {
      "data": ["Jan", "Feb", "Mar", "Apr", "May", "Jun"],
    },
    "yAxis": {"show": true, "name": "Amount"},
    "series": [
      {
        "name": "Revenue",
        "data": [820, 932, 901, 934, 1290, 1330],
        "color": "#5470C6",
      },
      {
        "name": "Profit",
        "data": [320, 432, 401, 434, 590, 630],
        "color": "#91CC75",
      },
    ],
    "barWidth": 12,
    "isStacked": false,
  };

  // Switch types seamlessly:
  void switchToPie() => setState(() => _currentType = ChartType.pie);
  void switchToLine() => setState(() => _currentType = ChartType.line);
  void switchToBar() => setState(() => _currentType = ChartType.bar);

  ChartType _currentType = ChartType.bar;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Toolbar
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _toggleButton('Bar', ChartType.bar),
            _toggleButton('Line', ChartType.line),
            _toggleButton('Pie', ChartType.pie),
          ],
        ),
        // Chart
        SizedBox(
          height: 300,
          child: TenunChartJson(
            jsonConfig: _salesJson,
            forceType: _currentType,
          ),
        ),
      ],
    );
  }

  Widget _toggleButton(String label, ChartType type) {
    final isSelected = _currentType == type;
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: ElevatedButton(
        onPressed: () => setState(() => _currentType = type),
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? Colors.blue : Colors.grey[300],
          foregroundColor: isSelected ? Colors.white : Colors.black,
        ),
        child: Text(label),
      ),
    );
  }
}
