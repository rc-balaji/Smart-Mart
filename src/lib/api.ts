import { ensureAnonymousUser } from './firebase';

const BASE = (process.env.EXPO_PUBLIC_API_BASE_URL || '').replace(/\/$/, '');

export type CartItem = { cartItemId:string; productId:string; name:string; pack:string; qty:number; unitPrice:number; lineTotal:number };
export type CustomerState = {
  session: null | { sessionId:string; trolleyId:string; status:string; orderId?:string };
  cart: CartItem[];
  total: number;
  order?: null | { orderId:string; total:number; method:string; paymentStatus:string; orderStatus:string };
};

async function request(action:string, payload:Record<string,unknown> = {}): Promise<CustomerState> {
  if (!BASE) throw new Error('API base URL is not configured.');
  const user = await ensureAnonymousUser();
  const token = await user.getIdToken();
  const res = await fetch(`${BASE}/api/customer/action`, {
    method:'POST',
    headers:{'content-type':'application/json','authorization':`Bearer ${token}`},
    body:JSON.stringify({action,payload,requestId:`REQ-${Date.now()}-${Math.random().toString(36).slice(2)}`})
  });
  const data = await res.json();
  if (!res.ok || !data.ok) throw new Error(data.error || 'Request failed');
  return data.data;
}

export const api = {
  state: () => request('STATE'),
  claimTrolley: (trolleyCode:string) => request('CLAIM_TROLLEY',{trolleyCode}),
  addProduct: (productCode:string) => request('ADD_PRODUCT',{productCode}),
  changeQty: (cartItemId:string, quantity:number) => request('CHANGE_QTY',{cartItemId,quantity}),
  checkout: (method:'CASH'|'UPI'|'QR') => request('CHECKOUT',{method}),
};
