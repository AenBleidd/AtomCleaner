program AtomCleaner;

{$APPTYPE CONSOLE}

uses
  SysUtils, Windows;

procedure GarbageCollectAtoms;
var i, len : integer;
    cstrAtomName: array [0 .. 1024] of char;
    AtomName, Value, procName: string;
    ProcID,lastError : cardinal;
    countDelphiProcs, countActiveProcs, countRemovedProcs, countCantRemoveProcs, countUnknownProcs : integer;

    // gets program's name from process' handle
    function getProcessFileName(Handle: THandle): string;
    begin
      Result := '';
      { not used anymore
      try
        SetLength(Result, MAX_PATH);
        if GetModuleFileNameEx(Handle, 0, PChar(Result), MAX_PATH) > 0 then
          SetLength(Result, StrLen(PChar(Result)))
        else
          Result := '';
        except
      end;
      }
    end;

    // gets the last 8 digits from the given atomname and try to convert them to and integer
    function getProcessIdFromAtomName(name:string):cardinal;
    var l : integer;
    begin
      result := 0;
      l := Length(name);
      if (l > 8) then
      begin
        try
          result := StrToInt64('$' + copy(name,l-7,8));
          except
            // Ops! That should be an integer, but it's not!
            // So this was no created by a 'delphi' application and we must return 0, indicating that we could not obtain the process id from atom name.
            result := 0;
        end;
      end;
    end;

    // checks if the given procID is running
    // results: -1: we could not get information about the process, so we can't determine if is active or not
    //           0: the process is not active
    //           1: the process is active
    function isProcessIdActive(id: cardinal; var processName: string):integer;
    var Handle_ID: THandle;
    begin
      result := -1;
      try
        Handle_ID := OpenProcess(PROCESS_QUERY_INFORMATION or PROCESS_VM_READ, false, id);
        if (Handle_ID = 0) then
        begin
          result := 0;
        end
        else
        begin
          result := 1;
          // get program's name
          processName := getProcessFileName(Handle_ID);
          CloseHandle(Handle_ID);
        end;
        except
          result := -1;
      end;
    end;

    procedure Log(msg:string);
    begin
       WriteLn(msg);
    end;


begin

  // initialize the counters
  countDelphiProcs := 0;
  countActiveProcs := 0;
  countRemovedProcs := 0;
  countUnknownProcs := 0;

  // register some log
  Log('');
  Log('');
  Log('Searching Global Atom Table...');

  for i := $C000 to $FFFF do
  begin
    len := GlobalGetAtomName(i, cstrAtomName, 1024);
    if len > 0 then
    begin
      AtomName := StrPas(cstrAtomName);
      SetLength(AtomName, len);
      Value := AtomName;
      // if the atom was created by a 'delphi application', it should start with some of strings below
      if (pos('Delphi',Value) = 1) or
         (pos('ControlOfs',Value) = 1) or
         (pos('WndProcPtr',Value) = 1) or
         (pos('DlgInstancePtr',Value) = 1) then 
      begin
        // extract the process id that created the atom (the ProcID are the last 8 digits from atomname)
        ProcID := getProcessIdFromAtomName(value);
        if (ProcId > 0) then
        begin
          // that's a delphi process
          inc(countDelphiProcs);
          // register some log
          Log('');
          Log('AtomName: ' + value + ' - ProcID: ' + inttostr(ProcId) + ' - Atom Nº: ' + inttostr(i));
          case (isProcessIdActive(ProcID, procName)) of
            0: // process is not active
            begin
              // remove atom from atom table
              SetLastError(ERROR_SUCCESS);
              GlobalDeleteAtom(i);
              lastError := GetLastError();
              if lastError = ERROR_SUCCESS then
              begin
                // ok, the atom was removed with sucess
                inc(countRemovedProcs);
                // register some log
                Log('- LEAK! Atom was removed from Global Atom Table because ProcID is not active anymore!');
              end
              else
              begin
                // ops, the atom could not be removed
                inc(countCantRemoveProcs);
                // register some log
                Log('- Atom was not removed from Global Atom Table because function "GlobalDeleteAtom" has failed! Reason: ' + SysErrorMessage(lastError));
              end;
            end;
            1: // process is active
            begin
              inc(countActiveProcs);
              // register some log
              Log('- Process is active! Program: ' + procName);
            end;
            -1: // could not get information about process
            begin
              inc(countUnknownProcs);
              // register some log
              Log('- Could not get information about the process and the Atom will not be removed!');
            end;
          end;
        end;
      end;
    end;
  end;
  Log('');
  Log('Scan complete:');
  Log('- Delphi Processes: ' + IntTostr(countDelphiProcs) );
  Log('  - Active: ' + IntTostr(countActiveProcs) );
  Log('  - Removed: ' + IntTostr(countRemovedProcs) );
  Log('  - Not Removed: ' + IntTostr(countCantRemoveProcs) );
  Log('  - Unknown: ' + IntTostr(countUnknownProcs) );
end;

begin
  GarbageCollectAtoms;
end.
