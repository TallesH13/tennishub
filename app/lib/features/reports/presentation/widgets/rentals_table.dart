import 'package:material_ui/material_ui.dart';
import 'package:tennishub/core/formatting/br_format.dart';
import 'package:tennishub/features/reports/domain/rental.dart';

/// Tabela das locações do relatório, com o cliente identificado.
class RentalsTable extends StatelessWidget {
  const RentalsTable({super.key, required this.rentals});

  final List<Rental> rentals;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Data e hora')),
            DataColumn(label: Text('Quadra')),
            DataColumn(label: Text('Cliente')),
            DataColumn(label: Text('Telefone')),
            DataColumn(label: Text('Valor'), numeric: true),
          ],
          rows: [
            for (final rental in rentals)
              DataRow(
                cells: [
                  DataCell(Text(BrFormat.dateTime(rental.startsAt))),
                  DataCell(Text(rental.courtName)),
                  DataCell(Text(rental.clientName)),
                  DataCell(Text(BrFormat.phone(rental.clientPhone))),
                  DataCell(
                    Text(
                      rental.valueCents == null
                          ? '—'
                          : BrFormat.money(rental.valueCents!),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
