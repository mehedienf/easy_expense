// Firebase configuration for EasyExpense with Google Sign-In
const firebaseConfig = {
  apiKey: "AIzaSyBeIjcFnE8vrpU5UfvDQt7FizT28nhIbuY",
  authDomain: "easyexpens.firebaseapp.com",
  databaseURL: "https://easyexpens-default-rtdb.firebaseio.com",
  projectId: "easyexpens",
  storageBucket: "easyexpens.firebasestorage.app",
  messagingSenderId: "950417547925",
  appId: "1:950417547925:web:1e4642c0c7d25a1b1a719c",
  measurementId: "G-JRF327LTN7"
};

// Initialize Firebase
if (typeof firebase !== 'undefined') {
  firebase.initializeApp(firebaseConfig);
}
