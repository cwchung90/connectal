
// Copyright (c) 2012 Nokia, Inc.

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

#include <errno.h>
#include <fcntl.h>
#include <linux/ioctl.h>
#include <linux/types.h>
#include <poll.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

#include "portal.h"

#include <sys/cdefs.h>
#include <android/log.h>
#define ALOGD(fmt, ...) __android_log_print(ANDROID_LOG_DEBUG, "PORTAL", fmt, __VA_ARGS__)
#define ALOGE(fmt, ...) __android_log_print(ANDROID_LOG_ERROR, "PORTAL", fmt, __VA_ARGS__)

#define PORTAL_ALLOC _IOWR('B', 10, PortalAlloc)
#define PORTAL_PUTGET _IOWR('B', 17, PortalMessage)
#define PORTAL_PUT _IOWR('B', 18, PortalMessage)
#define PORTAL_GET _IOWR('B', 19, PortalMessage)
#define PORTAL_REGS _IOWR('B', 20, PortalMessage)
#define PORTAL_SET_FCLK_RATE _IOWR('B', 40, PortalClockRequest)

PortalInterface portal;

void PortalInstance::close()
{
    if (fd > 0) {
        ::close(fd);
        fd = -1;
    }    
}

PortalInstance::PortalInstance(const char *instanceName, PortalIndications *indications)
    : indications(indications), fd(-1), instanceName(strdup(instanceName))
{
}

PortalInstance::~PortalInstance()
{
    close();
    if (instanceName)
        free(instanceName);
}

int PortalInstance::open()
{
    if (this->fd >= 0)
	return 0;

    FILE *pgfile = fopen("/sys/devices/amba.0/f8007000.devcfg/prog_done", "r");
    if (pgfile == 0) {
	ALOGE("failed to open /sys/devices/amba.0/f8007000.devcfg/prog_done %d\n", errno);
	return -1;
    }
    char line[128];
    fgets(line, sizeof(line), pgfile);
    if (line[0] != '1') {
	ALOGE("FPGA not programmed: %s\n", line);
	return -ENODEV;
    }
    fclose(pgfile);


    char path[128];
    snprintf(path, sizeof(path), "/dev/%s", instanceName);
    this->fd = ::open(path, O_RDWR);
    if (this->fd < 0) {
	ALOGE("Failed to open %s fd=%d errno=%d\n", path, this->fd, path);
	return -errno;
    }
    hwregs = (volatile unsigned int*)mmap(NULL, 2<<PAGE_SHIFT, PROT_READ|PROT_WRITE, MAP_SHARED, this->fd, 0);
    if (hwregs == MAP_FAILED) {
      ALOGE("Failed to mmap PortalHWRegs from fd=%d errno=%d\n", this->fd, errno);
      return -errno;
    }  
    portal.registerInstance(this);
    return 0;
}

PortalInstance *portalOpen(const char *instanceName)
{
    PortalInstance *instance = new PortalInstance(instanceName);
    instance->open();
    return instance;
}

int PortalInstance::sendMessage(PortalMessage *msg)
{
    int rc = open();
    if (rc != 0) {
	ALOGD("PortalInstance::sendMessage fd=%d rc=%d\n", fd, rc);
	return rc;
    }

    rc = ioctl(fd, PORTAL_PUT, msg);
    //ALOGD("sendmessage portal fd=%d rc=%d\n", fd, rc);
    if (rc)
        ALOGE("PortalInstance::sendMessage fd=%d rc=%d errno=%d:%s PUTGET=%x PUT=%x GET=%x\n", fd, rc, errno, strerror(errno),
                PORTAL_PUTGET, PORTAL_PUT, PORTAL_GET);
    return rc;
}

int PortalInstance::receiveMessage(PortalMessage *msg)
{
    int rc = open();
    if (rc != 0) {
	ALOGD("PortalInstance::receiveMessage fd=%d rc=%d\n", fd, rc);
	return 0;
    }

    int status  = ioctl(fd, PORTAL_GET, msg);
    if (status) {
        if (errno != EAGAIN)
            fprintf(stderr, "receiveMessage rc=%d errno=%d:%s\n", status, errno, strerror(errno));
        return 0;
    }
    return 1;
}

PortalInterface::PortalInterface()
  : fds(0), numFds(0)
{
}

PortalInterface::~PortalInterface()
{
    if (fds) {
        ::free(fds);
        fds = 0;
    }
}

int PortalInterface::registerInstance(PortalInstance *instance)
{
    numFds++;
    instances = (PortalInstance **)realloc(instances, numFds*sizeof(PortalInstance *));
    instances[numFds-1] = instance;
    fds = (struct pollfd *)realloc(fds, numFds*sizeof(struct pollfd));
    struct pollfd *pollfd = &fds[numFds-1];
    memset(pollfd, 0, sizeof(struct pollfd));
    pollfd->fd = instance->fd;
    pollfd->events = POLLIN;
    return 0;
}

int PortalInterface::alloc(size_t size, int *fd, PortalAlloc *portalAlloc)
{
    if (!portal.numFds) {
	ALOGE("%s No fds open\n", __FUNCTION__);
	return -ENODEV;
    }

    PortalAlloc alloc;
    memset(&alloc, 0, sizeof(alloc));
    void *ptr = 0;
    alloc.size = size;
    int rc = ioctl(portal.fds[0].fd, PORTAL_ALLOC, &alloc);
    if (rc)
      return rc;
    ptr = mmap(0, alloc.size, PROT_READ|PROT_WRITE, MAP_SHARED, alloc.fd, 0);
    fprintf(stderr, "alloc size=%d rc=%d alloc.fd=%d ptr=%p\n", size, rc, alloc.fd, ptr);
    if (fd)
      *fd = alloc.fd;
    if (portalAlloc)
      *portalAlloc = alloc;
    return 0;
}

int PortalInterface::free(int fd)
{
    return 0;
}

int PortalInterface::setClockFrequency(int clkNum, long requestedFrequency, long *actualFrequency)
{
    if (!portal.numFds) {
	ALOGE("%s No fds open\n", __FUNCTION__);
	return -ENODEV;
    }

    PortalClockRequest request;
    request.clknum = clkNum;
    request.requested_rate = requestedFrequency;
    int status = ioctl(portal.fds[0].fd, PORTAL_SET_FCLK_RATE, (long)&request);
    if (status == 0 && actualFrequency)
	*actualFrequency = request.actual_rate;
    if (status < 0)
	status = errno;
    return status;
}

int PortalInterface::dumpRegs()
{
    if (!portal.numFds) {
	ALOGE("%s No fds open\n", __FUNCTION__);
	return -ENODEV;
    }

    int foo = 0;
    int rc = ioctl(portal.fds[0].fd, PORTAL_REGS, &foo);
    return rc;
}

int PortalInterface::exec(idleFunc func)
{
    unsigned int *buf = new unsigned int[1024];
    PortalMessage *msg = (PortalMessage *)(buf);

    if (!portal.numFds) {
        ALOGE("PortalInterface::exec No fds open numFds=%d\n", portal.numFds);
        return -ENODEV;
    }

    int rc;
    while ((rc = poll(portal.fds, portal.numFds, -1)) >= 0) {
      for (int i = 0; i < portal.numFds; i++) {
	if (portal.fds[i].revents == 0)
	  continue;
	if (!portal.instances) {
	  fprintf(stderr, "No instances but rc=%d revents=%d\n", rc, portal.fds[i].revents);
	}

	PortalInstance *instance = portal.instances[i];
	memset(buf, 0, 1024);
	
	// sanity check, to see the status of interrupt source and enable
	volatile unsigned int int_src = *(instance->hwregs+0x0);
	volatile unsigned int int_en  = *(instance->hwregs+0x1);
	fprintf(stderr, "portal.instance[%d]: int_src=%08x int_en=%08x\n", i, int_src,int_en);

	// handle all messasges from this portal instance
	int messageReceived = instance->receiveMessage(msg);
	while (messageReceived) {
	  fprintf(stderr, "messageReceived: msg->size=%d msg->channel=%d\n", msg->size, msg->channel);
	  if (msg->size && instance->indications)
	    instance->indications->handleMessage(msg);
	  messageReceived = instance->receiveMessage(msg);
	}

	// re-enable interupt which was disabled by portal_isr
	*(instance->hwregs+0x1) = 1;
      }

      // rc of 0 indicates timeout
      if (rc == 0) {
	if (0)
	  ALOGD("poll timeout rc=%d errno=%d:%s func=%p\n", rc, errno, strerror(errno), func);
	if (func)
	  func();
      }
    }

    // return only in error case
    fprintf(stderr, "poll returned rc=%d errno=%d:%s\n", rc, errno, strerror(errno));
    return rc;
}
