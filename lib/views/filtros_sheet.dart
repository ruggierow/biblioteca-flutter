import 'package:flutter/material.dart';
import '../models/filtro_pesquisa.dart';
import '../models/grupos_store.dart';
import '../theme.dart';

/// A folha de filtros da pesquisa — o equivalente da barra "Pesquisar e
/// filtrar" do Mac e do Windows, num formato que cabe no polegar.
///
/// Trabalha sobre uma CÓPIA do filtro e devolve o resultado no `Navigator.pop`:
/// fechar arrastando a folha para baixo descarta as alterações.
class FiltrosSheet extends StatefulWidget {
  final FiltroPesquisa filtro;
  final List<Grupo> grupos;

  const FiltrosSheet({super.key, required this.filtro, required this.grupos});

  @override
  State<FiltrosSheet> createState() => _FiltrosSheetState();
}

class _FiltrosSheetState extends State<FiltrosSheet> {
  late final FiltroPesquisa _f = widget.filtro.copia();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: bibMuted.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                const Text('Filtros',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton(
                  onPressed: _f.quantosLigados == 0
                      ? null
                      : () => setState(() {
                            final t = _f.texto;
                            _f.limpar();
                            _f.texto = t;
                          }),
                  child: const Text('Limpar'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            _titulo('Status'),
            SegmentedButton<FiltroStatus>(
              segments: FiltroStatus.values
                  .map((s) => ButtonSegment(value: s, label: Text(s.rotulo)))
                  .toList(),
              selected: {_f.status},
              onSelectionChanged: (sel) => setState(() => _f.status = sel.first),
              showSelectedIcon: false,
            ),
            const SizedBox(height: 18),

            _titulo('Grupo de literatura'),
            DropdownButtonFormField<FiltroGrupo>(
              initialValue: _f.grupo,
              isExpanded: true,
              decoration: const InputDecoration(isDense: true),
              items: [
                const DropdownMenuItem(
                    value: FiltroGrupo.todos, child: Text('Todos os livros')),
                const DropdownMenuItem(
                    value: FiltroGrupo.qualquerUm, child: Text('Qualquer grupo')),
                ...widget.grupos.map((g) => DropdownMenuItem(
                    value: FiltroGrupo.especifico(g.id), child: Text(g.nome))),
              ],
              onChanged: (v) => setState(() => _f.grupo = v ?? FiltroGrupo.todos),
            ),
            const SizedBox(height: 6),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Só livros com foto'),
              value: _f.comFoto,
              onChanged: (v) => setState(() => _f.comFoto = v),
            ),
            const SizedBox(height: 8),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, _f),
                child: const Text('Pronto'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _titulo(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: bibMuted,
                letterSpacing: 0.4)),
      );
}
