const {getApps, initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const logger = require("firebase-functions/logger");

if (getApps().length === 0) {
  initializeApp();
}

const REGIAO = "southamerica-east1";
const ERROS_TOKEN_INVALIDO = new Set([
  "messaging/invalid-registration-token",
  "messaging/registration-token-not-registered",
]);

exports.enviarPushDeNotificacao = onDocumentCreated(
    {
      document: "notificacoes/{notificacaoId}",
      region: REGIAO,
      retry: false,
    },
    async (event) => {
      const notificacao = event.data?.data();
      const referencia = event.data?.ref;
      const destinatarioId = notificacao?.destinatarioId;

      if (!notificacao || !referencia || !destinatarioId) {
        logger.warn("Notificação sem destinatário; push ignorado.", {
          notificacaoId: event.params.notificacaoId,
        });
        return;
      }

      if (destinatarioId === "administradores") {
        const firestore = getFirestore();
        const administradores = await firestore
            .collection("usuarios")
            .where("tipoUsuario", "==", "admin")
            .get();

        await Promise.all(administradores.docs.map((adminDoc) => (
          firestore.collection("notificacoes").add({
            destinatarioId: adminDoc.id,
            remetenteId: notificacao.remetenteId || null,
            titulo: String(notificacao.titulo || "Nova atualização"),
            mensagem: String(notificacao.mensagem || ""),
            tipo: String(notificacao.tipo || "geral"),
            ...(notificacao.referenciaId ? {
              referenciaId: String(notificacao.referenciaId),
            } : {}),
            pedidoOrigemId: event.params.notificacaoId,
            lida: false,
            criadoEm: FieldValue.serverTimestamp(),
          })
        )));

        await referencia.delete();
        logger.info("Notificação distribuída aos administradores.", {
          notificacaoId: event.params.notificacaoId,
          destinatarios: administradores.size,
        });
        return;
      }

      const tokensSnapshot = await getFirestore()
          .collection("usuarios")
          .doc(destinatarioId)
          .collection("fcmTokens")
          .get();

      const dispositivos = tokensSnapshot.docs
          .map((doc) => ({doc, token: doc.get("token")}))
          .filter(({token}) => typeof token === "string" && token.length > 0);

      if (dispositivos.length === 0) {
        await referencia.update({
          pushStatus: "sem_dispositivos",
          pushAtualizadoEm: FieldValue.serverTimestamp(),
        });
        return;
      }

      const data = {
        notificacaoId: event.params.notificacaoId,
        tipo: String(notificacao.tipo || "geral"),
      };

      if (notificacao.referenciaId) {
        data.referenciaId = String(notificacao.referenciaId);
      }

      const parametrosLink = new URLSearchParams({tipo: data.tipo});
      if (data.referenciaId) {
        parametrosLink.set("referenciaId", data.referenciaId);
      }

      const resposta = await getMessaging().sendEachForMulticast({
        tokens: dispositivos.map(({token}) => token),
        notification: {
          title: String(notificacao.titulo || "CondoHub"),
          body: String(notificacao.mensagem || "Você recebeu uma atualização."),
        },
        data,
        android: {
          priority: "high",
          notification: {sound: "default"},
        },
        apns: {
          payload: {aps: {sound: "default"}},
        },
        webpush: {
          notification: {
            icon: "/icons/Icon-192.png",
            badge: "/icons/Icon-192.png",
          },
          fcmOptions: {link: `/?${parametrosLink.toString()}`},
        },
      });

      const exclusoes = [];
      resposta.responses.forEach((resultado, indice) => {
        if (!resultado.success &&
            ERROS_TOKEN_INVALIDO.has(resultado.error?.code)) {
          exclusoes.push(dispositivos[indice].doc.ref.delete());
        }
      });

      await Promise.all(exclusoes);
      await referencia.update({
        pushStatus: resposta.failureCount === 0 ? "enviado" : "parcial",
        pushSucessos: resposta.successCount,
        pushFalhas: resposta.failureCount,
        pushAtualizadoEm: FieldValue.serverTimestamp(),
      });

      logger.info("Push do CondoHub processado.", {
        notificacaoId: event.params.notificacaoId,
        sucessos: resposta.successCount,
        falhas: resposta.failureCount,
      });
    },
);
