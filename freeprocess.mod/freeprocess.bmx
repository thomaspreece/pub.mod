Rem
bbdoc: System/Execute Processes
End Rem
Module PUB.FreeProcess

ModuleInfo "Version: 1.04"
ModuleInfo "Framework: FreeProcess multi platform external process control"
ModuleInfo "License: zlib/libpng"
ModuleInfo "Copyright: Blitz Research Ltd"
ModuleInfo "Author: Simon Armstrong"
ModuleInfo "Modserver: BRL"

ModuleInfo "History: 1.04 Release"
ModuleInfo "History: Added Documentation, Added Detach and Attach Process Functions"
ModuleInfo "History: 1.03 Release"
ModuleInfo "History: Changed fork() to vfork() and exit() to _exit() to fix more hangs."
ModuleInfo "History: 1.02 Release"
ModuleInfo "History: Fixed a Linux hang when fork() is called."
ModuleInfo "History: Added SIGCHLD handling and fdReapZombies function."
ModuleInfo "History: 1.01 Release"
ModuleInfo "History: Inserts /Contents/MacOS/ into process path for Apple app packages"

Strict

' createproc - to launch external executable
' TPipeStream - nonblocking readlines with fd file handles

Import brl.stream
Import brl.linkedlist
Import brl.filesystem

Import "freeprocess.c"

'note: Once fdProcessStatus() returns 0 OR fdTerminateProcess() is called,
'processhandle should be assumed to be invalid, and neither function should be called
'again.
Extern
Function fdClose(fd)
Function fdRead:Long(fd,buffer:Byte Ptr,count:Long)
Function fdWrite:Long(fd,buffer:Byte Ptr,count:Long)
Function fdFlush(fd)
Function fdAvail(fd)
Function fdProcess(exe$,in_fd Ptr,out_fd Ptr,err_fd Ptr,flags)="fdProcess"
Function fdProcessStatus(processhandle)
Function fdTerminateProcess(processhandle)
End Extern

Const HIDECONSOLE=1

Type TPipeStream Extends TStream

	Field	readbuffer:Byte[4096]
	Field	bufferpos:Long
	Field	readhandle,writehandle

	Method Close()
		If readhandle 
			fdClose(readhandle)
			readhandle=0
		EndIf
		If writehandle 
			fdClose(writehandle)
			writehandle=0
		EndIf
	End Method

	Method Read:Long( buf:Byte Ptr,count:Long )
		Return fdRead(readhandle,buf,count)
	End Method

	Method Write:Long( buf:Byte Ptr,count:Long )
		Return fdWrite(writehandle,buf,count)
	End Method
	
	Method Flush()
		fdFlush(writehandle)
	End Method
		
	Method ReadAvail()
		Return fdAvail(readhandle)
	End Method
	
	Method ReadPipe:Byte[]()
		Local	bytes:Byte[],n
		n=ReadAvail()
		If n
			bytes=New Byte[n]
			Read(bytes,n)
			Return bytes
		EndIf	
	End Method
	
	Method ReadLine$()	'nonblocking - returns empty string if no data available
		Local	n:Long,r:Long,p0,p1,line$
		n=ReadAvail()
		If n
			If bufferpos+n>4096 n=4096-bufferpos
			If n<=0 RuntimeError "PipeStream ReadBuffer Overflow"
			r=Read(Varptr readbuffer[bufferpos],n)
			bufferpos:+r
		EndIf
		For n=0 To bufferpos
			If readbuffer[n]=10
				p1=n
				If (n>0)
					If readbuffer[n-1]=13 p1=n-1
				EndIf
				p0=0
				If readbuffer[0]=13 p0=1
				If p1>p0 line$=String.FromBytes(Varptr readbuffer[p0],p1-p0)
				n:+1
				bufferpos:-n
				If bufferpos MemMove(readbuffer,Varptr readbuffer[n],bufferpos)
				Return line$
			EndIf
		Next			
	End Method

	Function Create:TPipeStream( in,out )
		Local stream:TPipeStream=New TPipeStream
		stream.readhandle=in
		stream.writehandle=out
		Return stream
	End Function

End Type

Type TProcess
	Global ProcessList:TList 
	Field	name$
	Field	handle
	Field	pipe:TPipeStream
	Field	err:TPipeStream
	Field   detached:Int

	Method Detach()
		detached = True
		Return 1
	End Method
	
	Method Attach()
		detached = False
		Return 1
	End Method
	Method Status()
		If handle 
			If fdProcessStatus(handle) Return 1
			handle=0
		EndIf
		Return 0
	End Method
	
	Method Close()
		If pipe pipe.Close;pipe=Null
		If err err.Close;err=Null
	End Method
	
	Method Terminate()
		Local res
		If handle
			res=fdTerminateProcess( handle )
			handle=0
		EndIf
		Return res
	End Method

	Function Create:TProcess(name$,flags)
		Local	p:TProcess
		Local	infd,outfd,errfd	
?MacOS
		If FileType(name)=2
			Local a$=StripExt(StripDir(name))
			name:+"/Contents/MacOS/"+a$
		EndIf
?
		FlushZombies
		p=New TProcess
		p.name=name
		p.handle=fdProcess(p.name,Varptr infd,Varptr outfd,Varptr errfd,flags)
		If Not p.handle Return Null
		p.pipe=TPipeStream.Create(infd,outfd)
		p.err=TPipeStream.Create(errfd,0)
		p.detached = False 
		If Not ProcessList ProcessList=New TList
		ProcessList.AddLast p
		Return p
	End Function
	
	Function FlushZombies()
		If Not ProcessList Return
		Local live:TList=New TList
		For Local p:TProcess=EachIn ProcessList
			If p.Status() live.AddLast p
		Next
		ProcessList=live
	End Function
	
	Function TerminateAll() NoDebug
		If Not ProcessList Return
		For Local p:TProcess=EachIn ProcessList
			If p.detached = False Then 
				p.Terminate
			EndIf
		Next
		ProcessList=Null
	End Function
	
End Type

Rem
bbdoc: Creates a process
returns: TProcess object that is linked to the process you have started
End Rem
Function CreateProcess:TProcess(cmd$,flags=0)
	Return TProcess.Create(cmd,flags)
End Function

Rem
bbdoc: Checks status of program
returns: 1 if program is still running and 0 otherwise.
End Rem
Function ProcessStatus:Int(process:TProcess)
	Return process.Status()
End Function

Rem
bbdoc: Detaches a process from program
End Rem
Function DetachProcess:Int(process:TProcess)
	Return process.Detach()
End Function

Rem
bbdoc: Reattaches a process from program
End Rem
Function AttachProcess:Int(process:TProcess)
	Return process.Attach()
End Function

Rem
bbdoc: End Process
returns: 1 if termination of program was successful and 0 otherwise.
End Rem
Function TerminateProcess:Int(process:TProcess)
	Return process.Terminate()
End Function

OnEnd TProcess.TerminateAll
