<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="theme-color" content="#198754">
<title>Daily Hisab</title>
<link rel="manifest" href="manifest.json">

<style>
*{box-sizing:border-box}

body{
margin:0;
font-family:Arial,sans-serif;
background:#f5f7f9;
color:#222;
}

header{
background:#198754;
color:white;
padding:16px;
text-align:center;
}

header h1{
margin:0;
}

nav{
display:flex;
overflow-x:auto;
background:white;
position:sticky;
top:0;
z-index:10;
box-shadow:0 1px 5px #ccc;
}

nav button{
min-width:105px;
padding:13px 5px;
border:0;
background:white;
font-weight:bold;
}

nav button.active{
color:#198754;
border-bottom:3px solid #198754;
}

main{
max-width:900px;
margin:auto;
padding:14px;
}

.page{
display:none;
}

.page.active{
display:block;
}

.cards{
display:grid;
grid-template-columns:repeat(2,1fr);
gap:10px;
}

.card,.box,.entry{
background:white;
padding:14px;
border-radius:12px;
box-shadow:0 1px 5px #ddd;
margin-bottom:10px;
}

.card b{
display:block;
font-size:21px;
margin-top:6px;
}

.income{color:#198754}
.expense{color:#dc3545}
.receivable{color:#0d6efd}
.payable{color:#fd7e14}

label{
display:block;
font-weight:bold;
margin:10px 0 5px;
}

input,select,textarea{
width:100%;
padding:11px;
border:1px solid #ccc;
border-radius:8px;
font-size:16px;
}

textarea{
min-height:80px;
}

button.primary{
background:#198754;
color:white;
border:0;
padding:11px 16px;
border-radius:8px;
font-weight:bold;
margin-top:12px;
}

button.danger{
background:#dc3545;
color:white;
border:0;
padding:7px 10px;
border-radius:7px;
}

button.secondary{
background:#eee;
border:0;
padding:9px;
border-radius:7px;
margin-top:8px;
}

.row{
display:flex;
justify-content:space-between;
gap:10px;
align-items:center;
}

.muted{
color:#777;
}

.hidden{
display:none!important;
}

.login-screen{
min-height:100vh;
display:flex;
align-items:center;
justify-content:center;
padding:20px;
background:#f5f7f9;
}

.login-box{
width:100%;
max-width:400px;
background:white;
padding:25px;
border-radius:16px;
box-shadow:0 2px 12px #ccc;
}

.login-box h1{
text-align:center;
color:#198754;
}

.login-message{
color:#dc3545;
margin-top:12px;
text-align:center;
}

.status{
padding:8px;
text-align:center;
font-size:13px;
background:#e9f7ef;
color:#198754;
}

.empty{
text-align:center;
padding:30px;
color:#777;
}
</style>
</head>

<body>

<section id="loginScreen" class="login-screen">

<div class="login-box">

<h1>Daily Hisab</h1>

<p class="muted" style="text-align:center">
Login to continue
</p>

<label>Email</label>

<input
id="loginEmail"
type="email"
placeholder="Enter email"
autocomplete="username"
>

<label>Password</label>

<input
id="loginPassword"
type="password"
placeholder="Enter password"
autocomplete="current-password"
>

<button
class="primary"
style="width:100%"
id="loginButton"
>
Login
</button>

<div
id="loginMessage"
class="login-message"
></div>

</div>

</section>

<div id="app" class="hidden">

<header>

<h1>Daily Hisab</h1>

<small id="userEmail"></small>

<br>

<button
id="logoutButton"
class="secondary"
>
Logout
</button>

</header>

<div id="syncStatus" class="status">
Connecting to cloud...
</div>

<nav>

<button
class="navButton active"
data-page="dashboardPage"
>
Dashboard
</button>

<button
class="navButton"
data-page="transactionPage"
>
Transaction
</button>

<button
class="navButton"
data-page="partyPage"
>
Parties
</button>

<button
class="navButton"
data-page="productionPage"
>
Production
</button>

<button
class="navButton"
data-page="historyPage"
>
History
</button>

</nav>

<main>

<section id="dashboardPage" class="page active">

<h2>Dashboard</h2>

<div class="cards">

<div class="card">
Income
<b class="income" id="totalIncome">
₹0.00
</b>
</div>

<div class="card">
Expense
<b class="expense" id="totalExpense">
₹0.00
</b>
</div>

<div class="card">
Balance
<b id="totalBalance">
₹0.00
</b>
</div>

<div class="card">
Receivable
<b class="receivable" id="totalReceivable">
₹0.00
</b>
</div>

<div class="card">
Payable
<b class="payable" id="totalPayable">
₹0.00
</b>
</div>

<div class="card">
Production
<b id="totalProduction">
0
</b>
</div>

</div>

<h2>Recent Transactions</h2>

<div id="recentTransactions"></div>

</section>
  <section id="transactionPage" class="page">

<h2>Add Transaction</h2>

<div class="box">

<label>Date</label>

<input
type="date"
id="transactionDate"
>

<label>Type</label>

<select id="transactionType">

<option value="income">
Income
</option>

<option value="expense">
Expense
</option>

<option value="receivable">
Receivable
</option>

<option value="payable">
Payable
</option>

<option value="payment_received">
Payment Received
</option>

<option value="payment_made">
Payment Made
</option>

</select>

<label>Party / Person</label>

<input
id="transactionParty"
placeholder="Customer / Supplier"
>

<label>Description</label>

<textarea
id="transactionDescription"
placeholder="Description"
></textarea>

<label>Amount</label>

<input
id="transactionAmount"
type="number"
step="0.01"
min="0"
placeholder="0.00"
>

<button
class="primary"
id="addTransactionButton"
>
Save Transaction
</button>

<p id="transactionMessage"></p>

</div>

</section>


<section id="partyPage" class="page">

<h2>Parties</h2>

<div class="box">

<label>Party Name</label>

<input
id="partyName"
placeholder="Enter party name"
>

<label>Opening Balance</label>

<input
id="partyOpening"
type="number"
step="0.01"
placeholder="0.00"
>

<label>Opening Type</label>

<select id="partyOpeningType">

<option value="none">
None
</option>

<option value="receivable">
Receivable
</option>

<option value="payable">
Payable
</option>

</select>

<button
class="primary"
id="addPartyButton"
>
Add Party
</button>

</div>

<div id="partyList"></div>

</section>


<section id="productionPage" class="page">

<h2>Production</h2>

<div class="box">

<label>Date</label>

<input
type="date"
id="productionDate"
>

<label>Product</label>

<input
id="productionProduct"
placeholder="Product name"
>

<label>Quantity</label>

<input
id="productionQuantity"
type="number"
step="0.01"
placeholder="Quantity"
>

<label>Unit</label>

<input
id="productionUnit"
placeholder="kg / pcs / box"
>

<button
class="primary"
id="addProductionButton"
>
Save Production
</button>

</div>

<div id="productionList"></div>

</section>


<section id="historyPage" class="page">

<h2>Transaction History</h2>

<div class="box">

<label>Search</label>

<input
id="historySearch"
placeholder="Search party or description"
>

</div>

<div id="historyList"></div>

</section>


</main>

</div>


<script type="module">

import { initializeApp }

from "https://www.gstatic.com/firebasejs/12.18.0/firebase-app.js";


import {

getAuth,

signInWithEmailAndPassword,

onAuthStateChanged,

signOut

}

from "https://www.gstatic.com/firebasejs/12.18.0/firebase-auth.js";


import {

getFirestore,

collection,

addDoc,

deleteDoc,

doc,

onSnapshot,

query,

orderBy,

serverTimestamp

}

from "https://www.gstatic.com/firebasejs/12.18.0/firebase-firestore.js";


const firebaseConfig = {

apiKey:
"AIzaSyBR7zDhLXHp8-sjIE1ibZ37SQgn2PQLwXk",

authDomain:
"jalu-bakery-daily-hisab.firebaseapp.com",

projectId:
"jalu-bakery-daily-hisab",

storageBucket:
"jalu-bakery-daily-hisab.firebasestorage.app",

messagingSenderId:
"887651742802",

appId:
"1:887651742802:web:f0521ad6fb0adfcf3ddb8b"

};


const app =
initializeApp(firebaseConfig);

const auth =
getAuth(app);

const db =
getFirestore(app);


let entries = [];

let parties = [];

let productions = [];

let unsubscribeEntries = null;

let unsubscribeParties = null;

let unsubscribeProductions = null;


const loginScreen =
document.getElementById("loginScreen");

const appScreen =
document.getElementById("app");

const loginEmail =
document.getElementById("loginEmail");

const loginPassword =
document.getElementById("loginPassword");

const loginButton =
document.getElementById("loginButton");

const loginMessage =
document.getElementById("loginMessage");


async function loginUser(){

const email =
loginEmail.value.trim();

const password =
loginPassword.value;

loginMessage.textContent = "";

if(!email || !password){

loginMessage.textContent =
"Please enter email and password.";

return;

}

loginButton.disabled = true;

loginButton.textContent =
"Logging in...";

try{

await signInWithEmailAndPassword(
auth,
email,
password
);

}catch(error){

console.error(error);

loginMessage.textContent =
"Login failed. Check your email and password.";

loginButton.disabled = false;

loginButton.textContent =
"Login";

}

}


loginButton.addEventListener(
"click",
loginUser
);


loginPassword.addEventListener(
"keydown",
function(event){

if(event.key === "Enter"){

loginUser();

}

}
);


document
.getElementById("logoutButton")
.addEventListener(
"click",
async function(){

await signOut(auth);

}
);


onAuthStateChanged(
auth,
function(user){

if(user){

loginScreen.classList.add(
"hidden"
);

appScreen.classList.remove(
"hidden"
);

document.getElementById(
"userEmail"
).textContent =
user.email || "";

startCloudSync();

}else{

loginScreen.classList.remove(
"hidden"
);

appScreen.classList.add(
"hidden"
);

stopCloudSync();

}

}
);


document
.querySelectorAll(".navButton")
.forEach(function(button){

button.addEventListener(
"click",
function(){

document
.querySelectorAll(".navButton")
.forEach(function(b){

b.classList.remove("active");

});


button.classList.add("active");


document
.querySelectorAll(".page")
.forEach(function(page){

page.classList.remove("active");

});


document
.getElementById(
button.dataset.page
)
.classList.add("active");

}

);

});


function today(){

const d = new Date();

return d.getFullYear()
+ "-"
+ String(d.getMonth()+1)
.padStart(2,"0")
+ "-"
+ String(d.getDate())
.padStart(2,"0");

}


document.getElementById(
"transactionDate"
).value = today();


document.getElementById(
"productionDate"
).value = today();


function startCloudSync(){

stopCloudSync();

const entriesQuery =
query(
collection(db,"entries"),
orderBy("createdAt","desc")
);

unsubscribeEntries =
onSnapshot(
entriesQuery,
function(snapshot){

entries =
snapshot.docs.map(function(item){

return {
id:item.id,
...item.data()
};

});

renderAll();

document.getElementById(
"syncStatus"
).textContent =
"☁️ Data synchronized";

},
function(error){

console.error(error);

document.getElementById(
"syncStatus"
).textContent =
"Cloud sync error";

}
);


const partiesQuery =
query(
collection(db,"parties"),
orderBy("createdAt","desc")
);

unsubscribeParties =
onSnapshot(
partiesQuery,
function(snapshot){

parties =
snapshot.docs.map(function(item){

return {
id:item.id,
...item.data()
};

});

renderAll();

}
);


const productionQuery =
query(
collection(db,"production"),
orderBy("createdAt","desc")
);

unsubscribeProductions =
onSnapshot(
productionQuery,
function(snapshot){

productions =
snapshot.docs.map(function(item){

return {
id:item.id,
...item.data()
};

});

renderAll();

}
);

}


function stopCloudSync(){

if(unsubscribeEntries){

unsubscribeEntries();

unsubscribeEntries = null;

}

if(unsubscribeParties){

unsubscribeParties();

unsubscribeParties = null;

}

if(unsubscribeProductions){

unsubscribeProductions();

unsubscribeProductions = null;

}

entries = [];

parties = [];

productions = [];

}
/* ================= ADD TRANSACTION ================= */

document
.getElementById("addTransactionButton")
.addEventListener(
"click",
async function(){

const date =
document.getElementById(
"transactionDate"
).value;

const type =
document.getElementById(
"transactionType"
).value;

const party =
document.getElementById(
"transactionParty"
).value.trim();

const description =
document.getElementById(
"transactionDescription"
).value.trim();

const amount =
Number(
document.getElementById(
"transactionAmount"
).value
);

if(!date){

alert("Please select date.");

return;

}

if(!amount || amount <= 0){

alert("Please enter amount.");

return;

}

if(!auth.currentUser){

alert("Please login first.");

return;

}

try{

await addDoc(
collection(db,"entries"),
{

date:date,

type:type,

party:party,

description:description,

amount:amount,

userId:auth.currentUser.uid,

userEmail:auth.currentUser.email,

createdAt:serverTimestamp()

}
);

document.getElementById(
"transactionParty"
).value="";

document.getElementById(
"transactionDescription"
).value="";

document.getElementById(
"transactionAmount"
).value="";

alert("Transaction saved.");

}catch(error){

console.error(error);

alert(
"Could not save transaction."
);

}

});


/* ================= ADD PARTY ================= */

document
.getElementById("addPartyButton")
.addEventListener(
"click",
async function(){

const name =
document.getElementById(
"partyName"
).value.trim();

const opening =
Number(
document.getElementById(
"partyOpening"
).value
) || 0;

const openingType =
document.getElementById(
"partyOpeningType"
).value;

if(!name){

alert("Please enter party name.");

return;

}

if(!auth.currentUser){

alert("Please login first.");

return;

}

try{

await addDoc(
collection(db,"parties"),
{

name:name,

opening:opening,

openingType:openingType,

userId:auth.currentUser.uid,

userEmail:auth.currentUser.email,

createdAt:serverTimestamp()

}
);

document.getElementById(
"partyName"
).value="";

document.getElementById(
"partyOpening"
).value="";

alert("Party saved.");

}catch(error){

console.error(error);

alert(
"Could not save party."
);

}

});


/* ================= ADD PRODUCTION ================= */

document
.getElementById("addProductionButton")
.addEventListener(
"click",
async function(){

const date =
document.getElementById(
"productionDate"
).value;

const product =
document.getElementById(
"productionProduct"
).value.trim();

const quantity =
Number(
document.getElementById(
"productionQuantity"
).value
);

const unit =
document.getElementById(
"productionUnit"
).value.trim();

if(!date){

alert("Please select date.");

return;

}

if(!product){

alert("Please enter product.");

return;

}

if(!quantity || quantity <= 0){

alert("Please enter quantity.");

return;

}

if(!auth.currentUser){

alert("Please login first.");

return;

}

try{

await addDoc(
collection(db,"production"),
{

date:date,

product:product,

quantity:quantity,

unit:unit,

userId:auth.currentUser.uid,

userEmail:auth.currentUser.email,

createdAt:serverTimestamp()

}
);

document.getElementById(
"productionProduct"
).value="";

document.getElementById(
"productionQuantity"
).value="";

document.getElementById(
"productionUnit"
).value="";

alert("Production saved.");

}catch(error){

console.error(error);

alert(
"Could not save production."
);

}

});


/* ================= DELETE TRANSACTION ================= */

window.deleteTransaction =
async function(id){

if(!confirm(
"Delete this transaction?"
)){

return;

}

try{

await deleteDoc(
doc(db,"entries",id)
);

}catch(error){

console.error(error);

alert("Delete failed.");

}

};


/* ================= DELETE PARTY ================= */

window.deleteParty =
async function(id){

if(!confirm(
"Delete this party?"
)){

return;

}

try{

await deleteDoc(
doc(db,"parties",id)
);

}catch(error){

console.error(error);

alert("Delete failed.");

}

};


/* ================= DELETE PRODUCTION ================= */

window.deleteProduction =
async function(id){

if(!confirm(
"Delete this production?"
)){

return;

}

try{

await deleteDoc(
doc(db,"production",id)
);

}catch(error){

console.error(error);

alert("Delete failed.");

}

};


/* ================= MONEY ================= */

function money(value){

return "₹" +
Number(value || 0)
.toLocaleString(
"en-IN",
{
minimumFractionDigits:2,
maximumFractionDigits:2
}
);

}
