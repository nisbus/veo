import { Component, OnInit } from '@angular/core';
import { WebsocketListenerService } from './websocket-listener.service'
@Component({
  selector: 'app-root',
  templateUrl: './app.component.html',
  styleUrls: ['./app.component.css']
})
export class AppComponent implements OnInit {
    title = 'VEO';
    public nodes = []
    // public containers = [];
    // public resources = {"memory": {"total":0, "used":0,"available":0},"cpu":{"count":0,"used":0,"available":0},"disk":{"total":0,"used":0,"available":0}}

    constructor(public streamer: WebsocketListenerService) {
	console.log("Starting");
    }

    ngOnInit() {
	this.streamer.messages.subscribe((message) => {
	    this.nodes = message
	});
    }
}
