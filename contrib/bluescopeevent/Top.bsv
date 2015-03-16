/* Copyright (c) 2014 Quanta Research Cambridge, Inc
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included
 * in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
 * OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */
import SpecialFIFOs::*;
import Vector::*;
import StmtFSM::*;
import FIFO::*;
import CtrlMux::*;
import Portal::*;
import HostInterface::*;
import BlueScopeEvent::*;
import ConnectalMemory::*;
import MemTypes::*;
import MemServer::*;
import MMU::*;
import SignalGen::*;
import BlueScopeEventRequest::*;
import BlueScopeEventIndication::*;
import MemServerRequest::*;
import MemServerIndication::*;
import MMURequest::*;
import MMUIndication::*;
import SignalGenRequest::*;
import SignalGenIndication::*;

`define BlueScopeEventSampleLength 512

typedef enum {HostMemServerIndication, HostMemServerRequest, HostMMURequest, HostMMUIndication, BlueScopeEventIndication, BlueScopeEventRequest, SignalGenIndication, SignalGenRequest} IfcNames deriving (Eq,Bits);

module mkConnectalTop(ConnectalTop#(PhysAddrWidth,DataBusWidth,Empty,1));

   BlueScopeEventIndicationProxy blueScopeEventIndicationProxy <- mkBlueScopeEventIndicationProxy(BlueScopeEventIndication);
   BlueScopeEventControl#(32) bs <- mkBlueScopeEvent(`BlueScopeEventSampleLength, blueScopeEventIndicationProxy.ifc);
   BlueScopeEventRequestWrapper blueScopeEventRequestWrapper <- mkBlueScopeEventRequestWrapper(BlueScopeEventRequest,bs.requestIfc);

   SignalGenIndicationProxy signalGenIndicationProxy <- mkSignalGenIndicationProxy(SignalGenIndication);
   SignalGenRequest sg <- mkSignalGen(bs.bse, signalGenIndicationProxy.ifc);
   SignalGenRequestWrapper signalGenRequestWrapper <- mkSignalGenRequestWrapper(SignalGenRequest,sg);


   Vector#(1, MemWriteClient#(DataBusWidth)) writeClients = newVector();
   writeClients[0] = bs.writeClient;

   MMUIndicationProxy hostMMUIndicationProxy <- mkMMUIndicationProxy(HostMMUIndication);
   MMU#(PhysAddrWidth) hostMMU <- mkMMU(0, True, hostMMUIndicationProxy.ifc);
   MMURequestWrapper hostMMURequestWrapper <- mkMMURequestWrapper(HostMMURequest, hostMMU.request);

   MemServerIndicationProxy hostMemServerIndicationProxy <- mkMemServerIndicationProxy(HostMemServerIndication);
   MemServer#(PhysAddrWidth,64,1) dma <- mkMemServer(nil, writeClients, cons(hostMMU,nil), hostMemServerIndicationProxy.ifc);
   MemServerRequestWrapper hostMemServerRequestWrapper <- mkMemServerRequestWrapper(HostMemServerRequest, dma.request);

   Vector#(8,StdPortal) portals;
   portals[0] = signalGenRequestWrapper.portalIfc;
   portals[1] = signalGenIndicationProxy.portalIfc; 
   portals[2] = blueScopeEventRequestWrapper.portalIfc;
   portals[3] = blueScopeEventIndicationProxy.portalIfc; 
   portals[4] = hostMemServerRequestWrapper.portalIfc;
   portals[5] = hostMemServerIndicationProxy.portalIfc; 
   portals[6] = hostMMURequestWrapper.portalIfc;
   portals[7] = hostMMUIndicationProxy.portalIfc;
   let ctrl_mux <- mkSlaveMux(portals);
   
   interface interrupt = getInterruptVector(portals);
   interface slave = ctrl_mux;
   interface masters = dma.masters;
endmodule


