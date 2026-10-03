import React, {useEffect, useMemo, useState} from 'react';
import {ActivityIndicator, Alert, Image, Modal, Pressable, SafeAreaView, ScrollView, StyleSheet, Text, TextInput, View} from 'react-native';
import {CameraView, useCameraPermissions} from 'expo-camera';
import {StatusBar} from 'expo-status-bar';
import {api, CustomerState} from './src/lib/api';

const EMPTY:CustomerState={session:null,cart:[],total:0,order:null};
const money=(n:number)=>`₹${Number(n||0).toLocaleString('en-IN',{maximumFractionDigits:2})}`;

type ScanMode='trolley'|'product'|null;

export default function App(){
  const [state,setState]=useState<CustomerState>(EMPTY);
  const [busy,setBusy]=useState(false);
  const [scanMode,setScanMode]=useState<ScanMode>(null);
  const [manual,setManual]=useState('');
  const [permission,requestPermission]=useCameraPermissions();
  const [scanned,setScanned]=useState(false);

  const itemCount=useMemo(()=>state.cart.reduce((a,x)=>a+x.qty,0),[state.cart]);

  useEffect(()=>{(async()=>{try{setBusy(true);setState(await api.state())}catch{}finally{setBusy(false)}})()},[]);

  async function run<T extends CustomerState>(fn:()=>Promise<T>){
    try{setBusy(true);const next=await fn();setState(next);return next}catch(e:any){Alert.alert('Smark Mart',e?.message||'Something went wrong');}finally{setBusy(false)}
  }

  async function openScanner(mode:Exclude<ScanMode,null>){
    if(!permission?.granted){const p=await requestPermission();if(!p.granted){Alert.alert('Camera permission','Allow camera access to scan QR/barcodes.');return}}
    setScanned(false);setScanMode(mode);
  }
  async function onCode(code:string){
    if(scanned)return;setScanned(true);setScanMode(null);
    if(scanMode==='trolley') await run(()=>api.claimTrolley(code));
    if(scanMode==='product') await run(()=>api.addProduct(code));
  }
  async function useManual(){
    const code=manual.trim();if(!code)return;
    setManual('');
    if(!state.session) await run(()=>api.claimTrolley(code));
    else await run(()=>api.addProduct(code));
  }

  if(busy && !state.session && !manual){
    return <SafeAreaView style={styles.center}><StatusBar style="dark"/><ActivityIndicator size="large"/><Text style={styles.muted}>Connecting Smark Mart…</Text></SafeAreaView>
  }

  return <SafeAreaView style={styles.safe}><StatusBar style="light"/>
    <View style={styles.header}><View style={styles.brandRow}><Image source={require("./assets/icon.png")} style={styles.brandIcon}/><View><Text style={styles.brand}>Smark Mart</Text><Text style={styles.headerSub}>Scan • Shop • Pay • Go</Text></View></View><View style={styles.dot}/></View>
    <ScrollView contentContainerStyle={styles.body} keyboardShouldPersistTaps="handled">
      {!state.session ? <>
        <View style={styles.heroCard}><Text style={styles.eyebrow}>STEP 1</Text><Text style={styles.h1}>Pick a trolley</Text><Text style={styles.muted}>Scan the QR attached to the trolley. No signup or phone number needed.</Text>
          <Pressable style={styles.primary} onPress={()=>openScanner('trolley')}><Text style={styles.primaryText}>Scan Trolley QR</Text></Pressable>
          <View style={styles.manualRow}><TextInput value={manual} onChangeText={setManual} placeholder="SM-TROLLEY-01" style={styles.input} autoCapitalize="characters"/><Pressable style={styles.smallBtn} onPress={useManual}><Text style={styles.smallBtnText}>Use</Text></Pressable></View>
        </View>
        <View style={styles.infoCard}><Text style={styles.infoTitle}>How it works</Text><Text style={styles.infoLine}>1  Scan trolley</Text><Text style={styles.infoLine}>2  Scan each product</Text><Text style={styles.infoLine}>3  Pay and show order at exit</Text></View>
      </> : <>
        <View style={styles.statusCard}><View><Text style={styles.eyebrow}>ACTIVE TROLLEY</Text><Text style={styles.trolley}>{state.session.trolleyId}</Text></View><Text style={styles.statusPill}>{state.session.status}</Text></View>
        {state.session.status==='ACTIVE' && <View style={styles.heroCard}><Text style={styles.eyebrow}>STEP 2</Text><Text style={styles.h1}>Scan your items</Text><Text style={styles.muted}>Scan before placing an item in the trolley.</Text>
          <Pressable style={styles.primary} onPress={()=>openScanner('product')}><Text style={styles.primaryText}>Scan Product</Text></Pressable>
          <View style={styles.manualRow}><TextInput value={manual} onChangeText={setManual} placeholder="SM-PRD001 / barcode" style={styles.input} autoCapitalize="characters"/><Pressable style={styles.smallBtn} onPress={useManual}><Text style={styles.smallBtnText}>Add</Text></Pressable></View>
        </View>}
        <View style={styles.card}><View style={styles.rowBetween}><Text style={styles.sectionTitle}>Your cart</Text><Text style={styles.muted}>{itemCount} items</Text></View>
          {state.cart.length===0?<Text style={styles.empty}>Your cart is empty.</Text>:state.cart.map(x=><View key={x.cartItemId} style={styles.item}><View style={{flex:1}}><Text style={styles.itemName}>{x.name}</Text><Text style={styles.muted}>{x.pack} · {money(x.unitPrice)}</Text><View style={styles.qtyRow}><Pressable style={styles.qtyBtn} onPress={()=>run(()=>api.changeQty(x.cartItemId,x.qty-1))}><Text style={styles.qtyTxt}>−</Text></Pressable><Text style={styles.qtyNum}>{x.qty}</Text><Pressable style={styles.qtyBtn} onPress={()=>run(()=>api.changeQty(x.cartItemId,x.qty+1))}><Text style={styles.qtyTxt}>+</Text></Pressable></View></View><Text style={styles.itemPrice}>{money(x.lineTotal)}</Text></View>)}
        </View>
        {state.session.status==='ACTIVE' && state.cart.length>0 && <View style={styles.card}><Text style={styles.eyebrow}>STEP 3</Text><View style={styles.rowBetween}><Text style={styles.sectionTitle}>Checkout</Text><Text style={styles.total}>{money(state.total)}</Text></View><Text style={styles.muted}>Choose how you’ll pay. Payment is confirmed at the admin counter for this prototype.</Text><View style={styles.payGrid}>{(['CASH','UPI','QR'] as const).map(m=><Pressable key={m} style={styles.payBtn} onPress={()=>run(()=>api.checkout(m))}><Text style={styles.payText}>{m}</Text></Pressable>)}</View></View>}
        {state.order && <View style={styles.done}><Text style={styles.doneIcon}>✓</Text><Text style={styles.doneTitle}>Order created</Text><Text style={styles.doneText}>{state.order.orderId}</Text><Text style={styles.doneText}>{state.order.paymentStatus} · {state.order.orderStatus}</Text><Text style={styles.doneHint}>Show this screen at the payment / dispatch counter.</Text></View>}
      </>}
    </ScrollView>
    {busy && <View style={styles.busy}><ActivityIndicator color="#fff"/></View>}
    <Modal visible={!!scanMode} animationType="slide" onRequestClose={()=>setScanMode(null)}>
      <View style={styles.scanPage}><View style={styles.scanHead}><Text style={styles.scanTitle}>{scanMode==='trolley'?'Scan trolley QR':'Scan product'}</Text><Pressable onPress={()=>setScanMode(null)}><Text style={styles.close}>Close</Text></Pressable></View>
        <CameraView style={styles.camera} facing="back" barcodeScannerSettings={{barcodeTypes:['qr','ean13','ean8','code128','upc_a','upc_e']}} onBarcodeScanned={scanned?undefined:(r)=>onCode(r.data)}/>
        <Text style={styles.scanHint}>Keep the code inside the frame.</Text>
      </View>
    </Modal>
  </SafeAreaView>
}

const styles=StyleSheet.create({
  safe:{flex:1,backgroundColor:'#F5F7FB'},center:{flex:1,alignItems:'center',justifyContent:'center',gap:12,backgroundColor:'#F5F7FB'},
  header:{backgroundColor:'#071827',paddingHorizontal:20,paddingTop:16,paddingBottom:22,flexDirection:'row',justifyContent:'space-between',alignItems:'center'},brandRow:{flexDirection:'row',alignItems:'center',gap:11},brandIcon:{width:42,height:42,borderRadius:12},brand:{color:'#fff',fontSize:24,fontWeight:'900'},headerSub:{color:'#9FE7DE',marginTop:3,fontSize:13},dot:{width:12,height:12,borderRadius:6,backgroundColor:'#2DD4BF'},
  body:{padding:16,paddingBottom:40,gap:14},heroCard:{backgroundColor:'#fff',borderRadius:24,padding:20,borderWidth:1,borderColor:'#E4EAF1'},card:{backgroundColor:'#fff',borderRadius:22,padding:18,borderWidth:1,borderColor:'#E4EAF1'},infoCard:{backgroundColor:'#EAFBF8',borderRadius:22,padding:18},infoTitle:{fontWeight:'900',fontSize:17,marginBottom:10},infoLine:{fontSize:15,marginVertical:5,color:'#134E4A'},
  eyebrow:{fontSize:11,fontWeight:'900',letterSpacing:1.2,color:'#0F766E'},h1:{fontSize:26,fontWeight:'900',marginTop:5,marginBottom:8,color:'#0F172A'},muted:{color:'#64748B',fontSize:13,lineHeight:19},primary:{marginTop:18,backgroundColor:'#0F766E',borderRadius:16,paddingVertical:16,alignItems:'center'},primaryText:{color:'#fff',fontWeight:'900',fontSize:16},manualRow:{flexDirection:'row',gap:8,marginTop:11},input:{flex:1,borderWidth:1,borderColor:'#CBD5E1',borderRadius:14,paddingHorizontal:13,paddingVertical:12,fontSize:15,backgroundColor:'#fff'},smallBtn:{backgroundColor:'#E2E8F0',paddingHorizontal:18,borderRadius:14,alignItems:'center',justifyContent:'center'},smallBtnText:{fontWeight:'900',color:'#0F172A'},
  statusCard:{backgroundColor:'#0F172A',borderRadius:22,padding:18,flexDirection:'row',alignItems:'center',justifyContent:'space-between'},trolley:{color:'#fff',fontSize:24,fontWeight:'900',marginTop:4},statusPill:{backgroundColor:'#D1FAE5',color:'#065F46',paddingHorizontal:10,paddingVertical:7,borderRadius:999,fontSize:11,fontWeight:'900'},sectionTitle:{fontSize:19,fontWeight:'900'},rowBetween:{flexDirection:'row',justifyContent:'space-between',alignItems:'center'},empty:{textAlign:'center',paddingVertical:28,color:'#94A3B8'},item:{flexDirection:'row',alignItems:'center',gap:10,paddingVertical:14,borderBottomWidth:1,borderBottomColor:'#EEF2F7'},itemName:{fontWeight:'800',fontSize:15},itemPrice:{fontWeight:'900'},qtyRow:{flexDirection:'row',alignItems:'center',gap:10,marginTop:9},qtyBtn:{width:34,height:34,borderRadius:10,borderWidth:1,borderColor:'#CBD5E1',alignItems:'center',justifyContent:'center'},qtyTxt:{fontSize:20,fontWeight:'900'},qtyNum:{minWidth:18,textAlign:'center',fontWeight:'900'},total:{fontWeight:'900',fontSize:22},payGrid:{flexDirection:'row',gap:8,marginTop:14},payBtn:{flex:1,borderRadius:14,borderWidth:1,borderColor:'#CBD5E1',paddingVertical:15,alignItems:'center'},payText:{fontWeight:'900'},done:{backgroundColor:'#ECFDF5',borderRadius:22,padding:20,alignItems:'center'},doneIcon:{fontSize:42,color:'#059669',fontWeight:'900'},doneTitle:{fontSize:22,fontWeight:'900',marginTop:4},doneText:{fontWeight:'700',marginTop:4,color:'#065F46'},doneHint:{marginTop:10,color:'#047857',textAlign:'center'},busy:{position:'absolute',right:18,bottom:18,width:48,height:48,borderRadius:24,backgroundColor:'#0F172A',alignItems:'center',justifyContent:'center'},
  scanPage:{flex:1,backgroundColor:'#020617',paddingTop:60,paddingHorizontal:16},scanHead:{flexDirection:'row',justifyContent:'space-between',alignItems:'center',marginBottom:18},scanTitle:{color:'#fff',fontWeight:'900',fontSize:21},close:{color:'#5EEAD4',fontWeight:'800'},camera:{flex:1,borderRadius:24,overflow:'hidden'},scanHint:{color:'#CBD5E1',textAlign:'center',paddingVertical:20}
});
