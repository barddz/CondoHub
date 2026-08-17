import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ResidentOption {
  final String id;
  final String nome;
  final String email;
  final String bloco;
  final String apartamento;

  const ResidentOption({
    required this.id,
    required this.nome,
    required this.email,
    required this.bloco,
    required this.apartamento,
  });

  String get rotulo {
    final unidade = [
      if (bloco.isNotEmpty) 'Bloco $bloco',
      if (apartamento.isNotEmpty) 'Apto $apartamento',
    ].join(' • ');
    return unidade.isEmpty ? '$nome • $email' : '$nome • $unidade';
  }

  String get termosBusca => '$nome $email $bloco $apartamento'.toLowerCase();
}

class ResidentSelector extends StatelessWidget {
  final ResidentOption? value;
  final ValueChanged<ResidentOption?> onChanged;

  const ResidentSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('usuarios')
          .where('tipoUsuario', isEqualTo: 'morador')
          .snapshots(),
      builder: (context, snapshot) {
        final moradores = (snapshot.data?.docs ?? []).map((doc) {
          final dados = doc.data();
          return ResidentOption(
            id: doc.id,
            nome: (dados['nomeCompleto'] ?? dados['nome'] ?? 'Morador')
                .toString(),
            email: (dados['email'] ?? '').toString(),
            bloco: (dados['bloco'] ?? '').toString(),
            apartamento: (dados['apartamento'] ?? '').toString(),
          );
        }).toList()
          ..sort(
              (a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));

        return Autocomplete<ResidentOption>(
          displayStringForOption: (option) => option.rotulo,
          optionsBuilder: (text) {
            final busca = text.text.trim().toLowerCase();
            if (busca.isEmpty) return moradores;
            return moradores
                .where((morador) => morador.termosBusca.contains(busca));
          },
          onSelected: onChanged,
          fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
            return TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: snapshot.connectionState != ConnectionState.waiting,
              onChanged: (texto) {
                if (value != null && texto != value!.rotulo) onChanged(null);
              },
              decoration: InputDecoration(
                labelText: 'Morador',
                hintText: snapshot.connectionState == ConnectionState.waiting
                    ? 'Carregando moradores...'
                    : 'Digite nome, e-mail, bloco ou apartamento',
                prefixIcon: const Icon(Icons.person_search_outlined),
                suffixIcon: value == null
                    ? const Icon(Icons.arrow_drop_down)
                    : const Icon(Icons.check_circle, color: Color(0xFF2E7D32)),
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(14),
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(maxWidth: 520, maxHeight: 280),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final option = options.elementAt(index);
                      return ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: Text(option.nome),
                        subtitle: Text([
                          option.email,
                          if (option.bloco.isNotEmpty) 'Bloco ${option.bloco}',
                          if (option.apartamento.isNotEmpty)
                            'Apto ${option.apartamento}',
                        ].join(' • ')),
                        onTap: () => onSelected(option),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
