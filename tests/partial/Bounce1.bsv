// Copyright (c) 2015 The Connectal Project

// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use, copy,
// modify, merge, publish, distribute, sublicense, and/or sell copies
// of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
// BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
// ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
import FIFOF::*;
import Pipe::*;

typedef struct {
	Bit#(16) a;
	Bit#(16) b;
} EchoPair deriving (Bits);

interface Bounce;
    interface PipeOut#(Bit#(32)) outDelay;
    interface PipeIn#(Bit#(32))  inDelay;
    interface PipeOut#(EchoPair) outPair;
    interface PipeIn#(EchoPair)  inPair;
endinterface

(* synthesize *)
module mkBounce1(Bounce);
    FIFOF#(Bit#(32)) delay <- mkSizedFIFOF(8);
    FIFOF#(EchoPair) delay2 <- mkSizedFIFOF(8);

    interface outDelay = toPipeOut(delay);
    interface inDelay = toPipeIn(delay);
    interface outPair = toPipeOut(delay2);
    interface inPair = toPipeIn(delay2);
endmodule