let e={},a=1;const s=new class{sendMessage(e,a){return new Promise((s,i)=>{if(!e||e.length<=0){i("api is invalid");return}if(null==window.nativeBridge){i(`
        channel named nativeBridge not found in flutter. please add channel:
        WebView(
          url: ...,
          ...
          javascriptChannels: {
            JavascriptChannel(
              name: nativeBridge,
              onMessageReceived: (message) {
                (instance of WebViewFlutterJavaScriptBridge).parseJavascriptMessage(message);
              },
            ),
          },
        )
        `);return}let t=this._pushCallback(s);this._postMessage(e,a,t),setTimeout(()=>{let e=this._popCallback(t);e&&e(null)},15e3)})}async receiveMessage(e){if(e.isResponseFlag){let a=this._popCallback(e.callbackId);a&&a(e.data)}else if(e.callbackId){if("searchDevice"===e.api){let a=await window.searchDevice();this._postMessage(e.api,a,e.callbackId,!0)}else if("getFeatures"===e.api){let a=await window.getFeatures(e.data);this._postMessage(e.api,a,e.callbackId,!0)}else if("btcGetAddress"===e.api){let a=await window.btcGetAddress(e.data);this._postMessage(e.api,a,e.callbackId,!0)}else if("monitorCharacteristic"===e.api){let a=await window.monitorCharacteristic(e.data);this._postMessage(e.api,a,e.callbackId,!0)}else this._postMessage(e.api,null,e.callbackId,!0)}}_postMessage(e,a,s,i=!1){let t=JSON.stringify({api:e,data:a,callbackId:s,isResponseFlag:i});window.nativeBridge.postMessage(t)}_pushCallback(s){let i=`api_${a++}`;return e[i]=s,i}_popCallback(a){if(e[a]){let s=e[a];return e[a]=null,s}return null}};window.jsBridgeHelper=s;