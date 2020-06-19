import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';

@Injectable({
  providedIn: 'root'
})
export class WebsocketListenerService {
    private websocket:any;
    messages : Observable<any>;
    status : string = "disconnected";
    constructor() {
	this.connect_socket();		
	this.messages = Observable.create(observer => {
	    this.websocket.onmessage = (event) => {
		try {
		    const data = JSON.parse(event.data);
		    observer.next(data);
		} catch (error) {
		    console.log("error parsing incoming data "+event.data);
		}
	    }
	});
    }

    connect_socket() {
	this.websocket = new WebSocket("ws://172.22.0.2:8086/websocket");
	this.websocket.onopen = (event) => {
	    console.log("Connected to websocket");
	    this.status = "connected";
	};
	this.websocket.onclose = (event) => {
	    console.log("Disconnected from websocket ");
	    console.log(event);
	    this.status = "disconnected";
	    this.connect_socket();
	}
    }
}
