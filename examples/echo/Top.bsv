// bsv libraries
import Vector::*;
import FIFO::*;
import Connectable::*;

// portz libraries
import Portal::*;
import Directory::*;
import CtrlMux::*;
import Portal::*;
import Leds::*;
import AxiMasterSlave::*;
import MemTypes::*;
import HostInterface::*;


// generated by tool
import EchoIndicationProxy::*;
import EchoRequestWrapper::*;
import SwallowWrapper::*;

// defined by user
import Echo::*;
import Swallow::*;

typedef enum {EchoIndication, EchoRequest, Swallow} IfcNames deriving (Eq,Bits);

module mkPortalTop#(HostType host)(StdPortalTop#(addrWidth));

   // instantiate user portals
   EchoIndicationProxy echoIndicationProxy <- mkEchoIndicationProxy(EchoIndication);
   EchoRequestInternal echoRequestInternal <- mkEchoRequestInternal(echoIndicationProxy.ifc);
   EchoRequestWrapper echoRequestWrapper <- mkEchoRequestWrapper(EchoRequest,echoRequestInternal.ifc);
   
   Swallow swallow <- mkSwallow();
   SwallowWrapper swallowWrapper <- mkSwallowWrapper(Swallow, swallow);
   
   Vector#(3,StdPortal) portals;
   portals[0] = swallowWrapper.portalIfc; 
   portals[1] = echoRequestWrapper.portalIfc; 
   portals[2] = echoIndicationProxy.portalIfc;
   
   // instantiate system directory
   StdDirectory dir <- mkStdDirectory(portals);
   let ctrl_mux <- mkSlaveMux(dir,portals);
   
   interface interrupt = getInterruptVector(portals);
   interface slave = ctrl_mux;
   interface masters = nil;
   interface leds = echoRequestInternal.leds;

endmodule : mkPortalTop
