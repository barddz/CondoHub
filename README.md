# CondoHub

Aplicativo de gestão condominial desenvolvido em Flutter para o Trabalho de
Conclusão de Curso de Engenharia de Computação.

O sistema reúne serviços para moradores, administração e portaria, incluindo
avisos, visitantes, reservas, encomendas, documentos e atendimento. A
autenticação é feita pelo Firebase Authentication e os dados são persistidos no
Cloud Firestore.

## Executar o projeto

1. Instale o Flutter e configure um navegador compatível.
2. Execute `flutter pub get`.
3. Inicie a aplicação com `flutter run -d chrome`.

O projeto já contém a configuração Firebase utilizada pelo CondoHub.

## Regras do Firestore

As regras de acesso estão versionadas em `firestore.rules` e separam as
permissões de moradores e administradores. Antes de publicar uma nova versão,
valide os principais fluxos em um projeto de teste e então aplique as regras:

```bash
firebase deploy --only firestore:rules
```

## Notificações híbridas

O CondoHub mantém o histórico e os popups em primeiro plano no Firestore. As
notificações em segundo plano são enviadas pelo Firebase Cloud Messaging por
uma Cloud Function localizada em `functions/`.

O projeto já contém a chave pública VAPID do Firebase usada pelo CondoHub. Caso
seja necessário testar outro projeto Firebase, ela pode ser sobrescrita ao
executar ou compilar:

```bash
flutter run -d chrome --dart-define=FCM_VAPID_KEY=SUA_CHAVE_PUBLICA
flutter build web --dart-define=FCM_VAPID_KEY=SUA_CHAVE_PUBLICA
```

Depois de validar em um projeto de teste, publique a função e as regras:

```bash
firebase deploy --only functions,firestore:rules
```
