@echo off
chcp 65001 >nul
setlocal EnableExtensions
set "DOTNET_CLI_TELEMETRY_OPTOUT=1"
title Quản lý sàn ký gửi đồ thời trang cũ

set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"
set "APP=%ROOT%\app\QuanLyKyGui"
set "DBDIR=%APP%\db"
set "BAK=%APP%\bak\QuanLyKyGuiThoiTrang_Full_20261115.bak"
set "DBNAME=QuanLyKyGuiThoiTrang"
set "SQLCMD=sqlcmd -S localhost -E -C -I -f 65001"

set "ACTION=%~1"
if "%ACTION%"=="" set "ACTION=run"

where dotnet >nul 2>&1
if errorlevel 1 (
    echo [LỖI] Không tìm thấy .NET SDK. Cài .NET 9 SDK rồi chạy lại.
    goto :fail
)

call :find_sqlcmd
if errorlevel 1 (
    echo [CẢNH BÁO] Không tìm thấy sqlcmd, các bước đụng tới SQL Server sẽ thất bại.
)

if /i "%ACTION%"=="run"     goto :do_run
if /i "%ACTION%"=="db"      goto :do_db
if /i "%ACTION%"=="build"   goto :do_build
if /i "%ACTION%"=="test"    goto :do_test
if /i "%ACTION%"=="capture" goto :do_capture
if /i "%ACTION%"=="export"  goto :do_export
if /i "%ACTION%"=="help"    goto :usage
if /i "%ACTION%"=="/?"      goto :usage
if /i "%ACTION%"=="-h"      goto :usage
goto :do_open


:do_run
echo === 1/3 Chuẩn bị cơ sở dữ liệu ===
call :ensure_db
if errorlevel 1 goto :fail
echo.
echo === 2/3 Build ứng dụng ===
call :build_app
if errorlevel 1 goto :fail
echo.
echo === 3/3 Khởi chạy ứng dụng ===
pushd "%APP%"
dotnet run --no-build
set "RC=%ERRORLEVEL%"
popd
if not "%RC%"=="0" goto :fail
goto :done


:do_open
echo === 1/3 Chuẩn bị cơ sở dữ liệu ===
call :ensure_db
if errorlevel 1 goto :fail
echo.
echo === 2/3 Build ứng dụng ===
call :build_app
if errorlevel 1 goto :fail
echo.
echo === 3/3 Mở màn hình "%ACTION%" ===
pushd "%APP%"
dotnet run --no-build -- --open %ACTION%
set "RC=%ERRORLEVEL%"
popd
if not "%RC%"=="0" goto :fail
goto :done


:do_db
echo === Tạo lại cơ sở dữ liệu %DBNAME% ===
call :create_db
if errorlevel 1 goto :fail
call :upgrade_workflow
if errorlevel 1 goto :fail
goto :done


:do_build
echo === Build ứng dụng ===
call :build_app
if errorlevel 1 goto :fail
goto :done


:do_test
echo === Kiểm thử ràng buộc CSDL ===
call :find_sqlcmd
if errorlevel 1 (
    echo [LỖI] Không tìm thấy sqlcmd.
    goto :fail
)
echo - 07_validation.sql
call :upgrade_workflow
if errorlevel 1 goto :fail
%SQLCMD% -i "%DBDIR%\07_validation.sql"
if errorlevel 1 goto :fail
echo.
echo - 08_negative_tests.sql
%SQLCMD% -i "%DBDIR%\08_negative_tests.sql"
if errorlevel 1 goto :fail
echo - 12_workflow_tests.sql
%SQLCMD% -b -i "%DBDIR%\12_workflow_tests.sql"
if errorlevel 1 goto :fail
echo - 13_edge_case_tests.sql
%SQLCMD% -b -i "%DBDIR%\13_edge_case_tests.sql"
if errorlevel 1 goto :fail
goto :done


:do_capture
call :ensure_db
if errorlevel 1 goto :fail
call :build_app
if errorlevel 1 goto :fail
echo === Chụp ảnh màn hình vào %ROOT%\screenshots ===
pushd "%APP%"
dotnet run --no-build -- --capture "%ROOT%\screenshots"
set "RC=%ERRORLEVEL%"
popd
if not "%RC%"=="0" goto :fail
goto :done


:do_export
call :ensure_db
if errorlevel 1 goto :fail
call :build_app
if errorlevel 1 goto :fail
echo === Xuất Excel mẫu vào %ROOT%\exports ===
pushd "%APP%"
dotnet run --no-build -- --export
set "RC=%ERRORLEVEL%"
popd
if not "%RC%"=="0" goto :fail
goto :done


:usage
echo Cách dùng: build.bat [run^|db^|build^|test^|capture^|export^|<màn hình>]
echo.
echo   run        Kiểm tra/tạo CSDL, build rồi mở ứng dụng  (mặc định)
echo   db         Tạo lại CSDL (ưu tiên khôi phục từ bak\)
echo   build      Chỉ build ứng dụng
echo   test       Chạy 07_validation.sql và 08_negative_tests.sql
echo   capture    Chụp lại 9 ảnh màn hình vào screenshots\
echo   export     Xuất 3 tệp Excel mẫu vào exports\
echo   help       Hiện trợ giúp này
echo.
echo   banhang, tiepnhan, duyet, tracuu, doanhthu, quyettoan, nhanvien
echo              Mở ứng dụng và vào thẳng màn hình tương ứng
echo.
echo Yêu cầu: .NET 9 SDK, SQL Server 2025, sqlcmd.
goto :done


:find_sqlcmd
where sqlcmd >nul 2>&1
if not errorlevel 1 exit /b 0
for %%P in ("%ProgramFiles%" "%ProgramFiles(x86)%") do (
    for /d %%D in ("%%~P\Microsoft SQL Server\Client SDK\ODBC\*") do (
        if exist "%%~fD\Tools\Binn\sqlcmd.exe" (
            set "PATH=%%~fD\Tools\Binn;%PATH%"
            exit /b 0
        )
    )
)
exit /b 1


:ensure_db
call :find_sqlcmd
if errorlevel 1 (
    echo [LỖI] Không tìm thấy sqlcmd. Cài SQL Server Command Line Utilities.
    exit /b 1
)
set "DBID="
for /f "usebackq delims=" %%i in (`%SQLCMD% -l 5 -b -r 1 -d master -h -1 -W -Q "SET NOCOUNT ON; SELECT ISNULL(CONVERT(varchar(10), DB_ID(N'%DBNAME%')), 'NULL')"`) do set "DBID=%%i"
if not defined DBID (
    echo [LỖI] Không kiểm tra được CSDL trên SQL Server tại localhost.
    echo Kiểm tra dịch vụ SQL Server ^(MSSQLSERVER^) và quyền Windows Authentication.
    exit /b 1
)
if /i "%DBID%"=="NULL" (
    echo Chưa có CSDL %DBNAME%, đang khởi tạo...
    call :create_db_scripts
    if errorlevel 1 exit /b 1
) else (
    echo Đã có CSDL %DBNAME%.
)
call :upgrade_workflow
if errorlevel 1 exit /b 1
exit /b 0

:upgrade_workflow
echo - Dong bo trigger, view va procedure theo source hien tai
%SQLCMD% -b -i "%DBDIR%\02_triggers.sql"
if errorlevel 1 exit /b %ERRORLEVEL%
%SQLCMD% -b -i "%DBDIR%\03_views.sql"
if errorlevel 1 exit /b %ERRORLEVEL%
%SQLCMD% -b -i "%DBDIR%\04_procedures.sql"
if errorlevel 1 exit /b %ERRORLEVEL%
echo - Cap nhat luong tiep nhan, xet duyet va dang ban
%SQLCMD% -b -i "%DBDIR%\11_tach_luong_ky_gui.sql"
if errorlevel 1 exit /b %ERRORLEVEL%
echo - Siet rang buoc toan ven du lieu
%SQLCMD% -b -i "%DBDIR%\14_hardening.sql"
exit /b %ERRORLEVEL%


:create_db
if exist "%BAK%" goto :create_db_restore
:create_db_scripts
for %%f in (00_create_database 01_schema 02_triggers 03_views 04_procedures 05_seed_master 06_seed_operations) do (
    echo - Chạy db\%%f.sql
    %SQLCMD% -b -i "%DBDIR%\%%f.sql"
    if errorlevel 1 exit /b 1
)
echo - Chạy db\07_validation.sql
%SQLCMD% -i "%DBDIR%\07_validation.sql"
echo - Chạy db\08_negative_tests.sql
%SQLCMD% -i "%DBDIR%\08_negative_tests.sql"
echo Đã tạo CSDL từ script.
exit /b 0

:create_db_restore
echo - Khôi phục từ %BAK%
%SQLCMD% -b -i "%DBDIR%\10_restore_database.sql"
if errorlevel 1 (
    echo [CẢNH BÁO] Khôi phục thất bại, chuyển sang chạy script tạo mới.
    goto :create_db_scripts
)
echo Đã khôi phục CSDL từ bản sao lưu.
exit /b 0


:build_app
pushd "%APP%"
dotnet build -v q -nologo -clp:ErrorsOnly
set "RC=%ERRORLEVEL%"
popd
if not "%RC%"=="0" (
    echo [LỖI] Build thất bại.
    exit /b 1
)
exit /b 0


:done
echo.
echo Hoàn tất.
if "%~1"=="" pause
exit /b 0


:fail
echo.
echo [DỪNG] Đã xảy ra lỗi, xem thông báo phía trên.
if "%~1"=="" pause
exit /b 1
