importScripts('https://www.gstatic.com/firebasejs/12.12.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/12.12.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyBjnDGQemhkrivhAEPkAw2LXV3lSxRJf3I',
  authDomain: 'condohubtcc.firebaseapp.com',
  projectId: 'condohubtcc',
  storageBucket: 'condohubtcc.firebasestorage.app',
  messagingSenderId: '372943485559',
  appId: '1:372943485559:web:0960793cc2eba203386472',
});

// A presença desta instância permite que o FCM exiba automaticamente as
// mensagens com payload de notificação quando o CondoHub estiver em segundo
// plano ou fechado.
firebase.messaging();
