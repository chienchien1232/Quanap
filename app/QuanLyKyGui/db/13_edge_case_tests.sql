USE [QuanLyKyGuiThoiTrang];
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
GO

/* ============================================================
   13_edge_case_tests.sql
   Kiểm thử biên và các lỗ hổng nghiệp vụ đã sửa ở 14_hardening.sql.
   Mỗi ca dựng dữ liệu riêng trong transaction rồi rollback.
   Mã lỗi 52000 = ca tự phát hiện sai lệch (không phải lỗi CSDL).
   ============================================================ */

IF OBJECT_ID('tempdb..#KQ') IS NOT NULL DROP TABLE #KQ;
CREATE TABLE #KQ (STT INT IDENTITY, MoTa NVARCHAR(300), KetQua VARCHAR(5), GhiChu NVARCHAR(1000));
GO

/* ------------------------------------------------------------
   #Ca: chạy một khối SQL, coi là PASS khi ROLLBACK sạch không lỗi.
   @LoiMongDoi = 0  -> khối phải chạy xong (hành vi cho phép)
   @LoiMongDoi > 0  -> khối phải bị chặn với đúng mã lỗi đó
   ------------------------------------------------------------ */
CREATE PROCEDURE #Ca
    @MoTa NVARCHAR(300), @Lenh NVARCHAR(MAX), @LoiMongDoi INT = 0
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Setup NVARCHAR(MAX) = N'
USE [QuanLyKyGuiThoiTrang];
DECLARE @MaKH INT = (SELECT TOP (1) MaKH FROM dbo.KHACH_HANG ORDER BY MaKH);
DECLARE @MaKH2 INT = (SELECT TOP (1) MaKH FROM dbo.KHACH_HANG WHERE MaKH <> @MaKH ORDER BY MaKH);
DECLARE @MaNV INT = (SELECT TOP (1) MaNV FROM dbo.NHAN_VIEN WHERE TrangThai = N''Đang làm việc'' ORDER BY MaNV);
DECLARE @MaDM INT = (SELECT TOP (1) MaDM FROM dbo.DANH_MUC ORDER BY MaDM);
DECLARE @MaPKG INT, @SP1 INT, @SP2 INT, @SP3 INT;
IF @MaKH IS NULL OR @MaNV IS NULL OR @MaDM IS NULL
    THROW 52000, N''Cần khách hàng, nhân viên đang làm việc và danh mục để kiểm tra.'', 1;
DECLARE @SanPham dbo.SanPhamKyGuiType;
INSERT @SanPham (MaDM, TenSP, TinhTrang, GiaDeXuat, TrangThaiTiepNhan)
VALUES (@MaDM, N''Món thử biên A'', N''Còn tốt'', 500000, N''Chờ xử lý''),
       (@MaDM, N''Món thử biên B'', N''Còn tốt'', 500000, N''Chờ xử lý''),
       (@MaDM, N''Món thử biên C'', N''Còn tốt'', 500000, N''Chờ xử lý'');
EXEC dbo.sp_TiepNhanPhieuKyGui @MaKH = @MaKH, @MaNV = @MaNV, @SanPham = @SanPham, @MaPKG = @MaPKG OUTPUT;
SELECT @SP1 = MIN(MaSP), @SP3 = MAX(MaSP) FROM dbo.SAN_PHAM WHERE MaPKG = @MaPKG;
SELECT @SP2 = MaSP FROM dbo.SAN_PHAM WHERE MaPKG = @MaPKG AND MaSP NOT IN (@SP1, @SP3);
';
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @Sql NVARCHAR(MAX) = @Setup + CHAR(13) + CHAR(10) + @Lenh;
        EXEC sys.sp_executesql @Sql;
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        IF @LoiMongDoi = 0
            INSERT #KQ VALUES (@MoTa, 'PASS', N'Đúng hành vi mong đợi.');
        ELSE
            INSERT #KQ VALUES (@MoTa, 'FAIL', CONCAT(N'Không bị chặn, lẽ ra phải trả lỗi ', @LoiMongDoi, N'.'));
    END TRY
    BEGIN CATCH
        DECLARE @Loi INT = ERROR_NUMBER(), @ThongBao NVARCHAR(1000) = ERROR_MESSAGE();
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        IF @Loi = @LoiMongDoi
            INSERT #KQ VALUES (@MoTa, 'PASS', CONCAT(@Loi, N': ', @ThongBao));
        ELSE
            INSERT #KQ VALUES (@MoTa, 'FAIL', CONCAT(N'Nhận lỗi ', @Loi, N' thay vì ', @LoiMongDoi, N': ', @ThongBao));
    END CATCH
END;
GO

/* ============================================================
   NHÓM 1 — KHOÁ ĐƠN HÀNG SAU KHI THU TIỀN  (lỗi A2, A3)
   ============================================================ */

EXEC #Ca N'[A2] Xoá chi tiết đơn đã thu MỘT PHẦN bị chặn', N'
    EXEC dbo.sp_DuyetSanPham @MaSP=@SP1, @KetQua=N''Đã chấp nhận'';
    EXEC dbo.sp_DuyetSanPham @MaSP=@SP2, @KetQua=N''Đã chấp nhận'';
    EXEC dbo.sp_DangBanSanPham @MaSP=@SP1, @GiaDangBan=300000;
    EXEC dbo.sp_DangBanSanPham @MaSP=@SP2, @GiaDangBan=300000;
    DECLARE @CT dbo.ChiTietDonHangType, @DH INT;
    INSERT @CT VALUES (@SP1, 0), (@SP2, 0);
    EXEC dbo.sp_TaoDonHang @MaKH=@MaKH, @MaNV=@MaNV, @ChiTiet=@CT, @MaDH=@DH OUTPUT;
    DECLARE @TT INT;
    EXEC dbo.sp_GhiNhanThanhToan @MaDH=@DH, @SoTien=300000, @PhuongThuc=N''Tiền mặt'', @MaTTDH=@TT OUTPUT;
    DELETE dbo.CHI_TIET_DON_HANG WHERE MaDH=@DH AND MaSP=@SP2;
', 50003;
GO

EXEC #Ca N'[A2] Xoá chi tiết đơn đã thu ĐỦ bị chặn', N'
    EXEC dbo.sp_DuyetSanPham @MaSP=@SP1, @KetQua=N''Đã chấp nhận'';
    EXEC dbo.sp_DuyetSanPham @MaSP=@SP2, @KetQua=N''Đã chấp nhận'';
    EXEC dbo.sp_DangBanSanPham @MaSP=@SP1, @GiaDangBan=300000;
    EXEC dbo.sp_DangBanSanPham @MaSP=@SP2, @GiaDangBan=300000;
    DECLARE @CT dbo.ChiTietDonHangType, @DH INT;
    INSERT @CT VALUES (@SP1, 0), (@SP2, 0);
    EXEC dbo.sp_TaoDonHang @MaKH=@MaKH, @MaNV=@MaNV, @ChiTiet=@CT, @MaDH=@DH OUTPUT;
    DECLARE @TT INT;
    EXEC dbo.sp_GhiNhanThanhToan @MaDH=@DH, @SoTien=600000, @PhuongThuc=N''Tiền mặt'', @MaTTDH=@TT OUTPUT;
    DELETE dbo.CHI_TIET_DON_HANG WHERE MaDH=@DH AND MaSP=@SP2;
', 50003;
GO

EXEC #Ca N'[A3] Sửa giá niêm yết sau khi đã thu đủ bị chặn', N'
    EXEC dbo.sp_DuyetSanPham @MaSP=@SP1, @KetQua=N''Đã chấp nhận'';
    EXEC dbo.sp_DangBanSanPham @MaSP=@SP1, @GiaDangBan=500000;
    DECLARE @CT dbo.ChiTietDonHangType, @DH INT;
    INSERT @CT VALUES (@SP1, 0);
    EXEC dbo.sp_TaoDonHang @MaKH=@MaKH, @MaNV=@MaNV, @ChiTiet=@CT, @MaDH=@DH OUTPUT;
    DECLARE @TT INT;
    EXEC dbo.sp_GhiNhanThanhToan @MaDH=@DH, @SoTien=500000, @PhuongThuc=N''Tiền mặt'', @MaTTDH=@TT OUTPUT;
    UPDATE dbo.CHI_TIET_DON_HANG SET GiaNiemYetLucBan = 900000 WHERE MaDH=@DH AND MaSP=@SP1;
', 50019;
GO

EXEC #Ca N'[A3] Sửa giảm giá sau khi đã thu đủ bị chặn', N'
    EXEC dbo.sp_DuyetSanPham @MaSP=@SP1, @KetQua=N''Đã chấp nhận'';
    EXEC dbo.sp_DangBanSanPham @MaSP=@SP1, @GiaDangBan=500000;
    DECLARE @CT dbo.ChiTietDonHangType, @DH INT;
    INSERT @CT VALUES (@SP1, 0);
    EXEC dbo.sp_TaoDonHang @MaKH=@MaKH, @MaNV=@MaNV, @ChiTiet=@CT, @MaDH=@DH OUTPUT;
    DECLARE @TT INT;
    EXEC dbo.sp_GhiNhanThanhToan @MaDH=@DH, @SoTien=500000, @PhuongThuc=N''Tiền mặt'', @MaTTDH=@TT OUTPUT;
    UPDATE dbo.CHI_TIET_DON_HANG SET GiamGia = 100000 WHERE MaDH=@DH AND MaSP=@SP1;
', 50019;
GO

EXEC #Ca N'[A3] Sửa chi tiết đơn đã Hoàn tất bị chặn', N'
    EXEC dbo.sp_DuyetSanPham @MaSP=@SP1, @KetQua=N''Đã chấp nhận'';
    EXEC dbo.sp_DangBanSanPham @MaSP=@SP1, @GiaDangBan=400000;
    DECLARE @CT dbo.ChiTietDonHangType, @DH INT;
    INSERT @CT VALUES (@SP1, 0);
    EXEC dbo.sp_TaoDonHang @MaKH=@MaKH, @MaNV=@MaNV, @ChiTiet=@CT, @MaDH=@DH OUTPUT;
    DECLARE @TT INT;
    EXEC dbo.sp_GhiNhanThanhToan @MaDH=@DH, @SoTien=400000, @PhuongThuc=N''Tiền mặt'', @MaTTDH=@TT OUTPUT;
    EXEC dbo.sp_HoanTatDonHang @MaDH=@DH;
    UPDATE dbo.CHI_TIET_DON_HANG SET GiaNiemYetLucBan = 450000 WHERE MaDH=@DH AND MaSP=@SP1;
', 50019;
GO

EXEC #Ca N'[A2] Xoá chi tiết đơn Chờ thanh toán CHƯA thu tiền vẫn được phép', N'
    EXEC dbo.sp_DuyetSanPham @MaSP=@SP1, @KetQua=N''Đã chấp nhận'';
    EXEC dbo.sp_DuyetSanPham @MaSP=@SP2, @KetQua=N''Đã chấp nhận'';
    EXEC dbo.sp_DangBanSanPham @MaSP=@SP1, @GiaDangBan=300000;
    EXEC dbo.sp_DangBanSanPham @MaSP=@SP2, @GiaDangBan=300000;
    DECLARE @CT dbo.ChiTietDonHangType, @DH INT;
    INSERT @CT VALUES (@SP1, 0), (@SP2, 0);
    EXEC dbo.sp_TaoDonHang @MaKH=@MaKH, @MaNV=@MaNV, @ChiTiet=@CT, @MaDH=@DH OUTPUT;
    DELETE dbo.CHI_TIET_DON_HANG WHERE MaDH=@DH AND MaSP=@SP2;
    IF NOT EXISTS (SELECT 1 FROM dbo.SAN_PHAM WHERE MaSP=@SP2 AND TrangThaiBan=N''Đang bán'')
        THROW 52000, N''Sản phẩm xoá khỏi đơn không trở lại Đang bán.'', 1;
';
GO

/* ============================================================
   NHÓM 2 — ĐƠN TỔNG 0 ĐỒNG / GIẢM GIÁ 50%  (lỗi A5)
   ============================================================ */

EXEC #Ca N'[A5] Giảm giá vượt 50% giá niêm yết bị chặn', N'
    EXEC dbo.sp_DuyetSanPham @MaSP=@SP1, @KetQua=N''Đã chấp nhận'';
    EXEC dbo.sp_DangBanSanPham @MaSP=@SP1, @GiaDangBan=200000;
    DECLARE @CT dbo.ChiTietDonHangType, @DH INT;
    INSERT @CT VALUES (@SP1, 100001);
    EXEC dbo.sp_TaoDonHang @MaKH=@MaKH, @MaNV=@MaNV, @ChiTiet=@CT, @MaDH=@DH OUTPUT;
', 51311;
GO

EXEC #Ca N'[A5] Giảm giá đúng 50% được phép, tổng đơn dương', N'
    EXEC dbo.sp_DuyetSanPham @MaSP=@SP1, @KetQua=N''Đã chấp nhận'';
    EXEC dbo.sp_DangBanSanPham @MaSP=@SP1, @GiaDangBan=200000;
    DECLARE @CT dbo.ChiTietDonHangType, @DH INT;
    INSERT @CT VALUES (@SP1, 100000);
    EXEC dbo.sp_TaoDonHang @MaKH=@MaKH, @MaNV=@MaNV, @ChiTiet=@CT, @MaDH=@DH OUTPUT;
    IF (SELECT SUM(GiaBanThucTe) FROM dbo.CHI_TIET_DON_HANG WHERE MaDH=@DH) <> 100000
        THROW 52000, N''Tổng tiền đơn không đúng 100.000.'', 1;
';
GO

EXEC #Ca N'[A5] Giảm giá 100% (đơn 0 đồng) bị chặn ở CSDL', N'
    EXEC dbo.sp_DuyetSanPham @MaSP=@SP1, @KetQua=N''Đã chấp nhận'';
    EXEC dbo.sp_DangBanSanPham @MaSP=@SP1, @GiaDangBan=100000;
    DECLARE @CT dbo.ChiTietDonHangType, @DH INT;
    INSERT @CT VALUES (@SP1, 100000);
    EXEC dbo.sp_TaoDonHang @MaKH=@MaKH, @MaNV=@MaNV, @ChiTiet=@CT, @MaDH=@DH OUTPUT;
', 51311;
GO

EXEC #Ca N'[A5] Chèn thẳng chi tiết 0 đồng vào đơn bị CHECK chặn', N'
    EXEC dbo.sp_DuyetSanPham @MaSP=@SP1, @KetQua=N''Đã chấp nhận'';
    EXEC dbo.sp_DangBanSanPham @MaSP=@SP1, @GiaDangBan=100000;
    DECLARE @CT dbo.ChiTietDonHangType, @DH INT;
    INSERT @CT VALUES (@SP1, 0);
    EXEC dbo.sp_TaoDonHang @MaKH=@MaKH, @MaNV=@MaNV, @ChiTiet=@CT, @MaDH=@DH OUTPUT;
    /* Vượt qua trigger bằng cách tắt tạm để chạm đúng CHECK của bảng */
    DISABLE TRIGGER dbo.TR_CTDH ON dbo.CHI_TIET_DON_HANG;
    UPDATE dbo.CHI_TIET_DON_HANG SET GiamGia = 100000 WHERE MaDH=@DH AND MaSP=@SP1;
', 547;
GO

/* ============================================================
   NHÓM 3 — GIAO DỊCH TREO  (lỗi A4)
   ============================================================ */

EXEC #Ca N'[A4] Huỷ đơn có giao dịch Chờ xử lý: đơn huỷ được, giao dịch chuyển Thất bại', N'
    EXEC dbo.sp_DuyetSanPham @MaSP=@SP1, @KetQua=N''Đã chấp nhận'';
    EXEC dbo.sp_DangBanSanPham @MaSP=@SP1, @GiaDangBan=200000;
    DECLARE @CT dbo.ChiTietDonHangType, @DH INT;
    INSERT @CT VALUES (@SP1, 0);
    EXEC dbo.sp_TaoDonHang @MaKH=@MaKH, @MaNV=@MaNV, @ChiTiet=@CT, @MaDH=@DH OUTPUT;
    DECLARE @TT INT;
    EXEC dbo.sp_GhiNhanThanhToan @MaDH=@DH, @SoTien=200000, @PhuongThuc=N''Tiền mặt'',
         @TrangThai=N''Chờ xử lý'', @MaTTDH=@TT OUTPUT;
    EXEC dbo.sp_HuyDonHang @MaDH=@DH, @LyDo=N''Khách đổi ý'';
    IF NOT EXISTS (SELECT 1 FROM dbo.DON_HANG WHERE MaDH=@DH AND TrangThai=N''Đã hủy'')
        THROW 52000, N''Đơn không chuyển Đã hủy.'', 1;
    IF EXISTS (SELECT 1 FROM dbo.THANH_TOAN_DON_HANG WHERE MaTTDH=@TT AND TrangThai=N''Chờ xử lý'')
        THROW 52000, N''Giao dịch treo chưa được đóng.'', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.SAN_PHAM WHERE MaSP=@SP1 AND TrangThaiBan=N''Đang bán'')
        THROW 52000, N''Sản phẩm không trở lại Đang bán sau khi huỷ đơn.'', 1;
';
GO

EXEC #Ca N'[A4] sp_CapNhatThanhToan đóng giao dịch treo thành Thất bại', N'
    EXEC dbo.sp_DuyetSanPham @MaSP=@SP1, @KetQua=N''Đã chấp nhận'';
    EXEC dbo.sp_DangBanSanPham @MaSP=@SP1, @GiaDangBan=200000;
    DECLARE @CT dbo.ChiTietDonHangType, @DH INT;
    INSERT @CT VALUES (@SP1, 0);
    EXEC dbo.sp_TaoDonHang @MaKH=@MaKH, @MaNV=@MaNV, @ChiTiet=@CT, @MaDH=@DH OUTPUT;
    DECLARE @TT INT;
    EXEC dbo.sp_GhiNhanThanhToan @MaDH=@DH, @SoTien=200000, @PhuongThuc=N''Tiền mặt'',
         @TrangThai=N''Chờ xử lý'', @MaTTDH=@TT OUTPUT;
    EXEC dbo.sp_CapNhatThanhToan @MaTTDH=@TT, @TrangThai=N''Thất bại'';
    IF NOT EXISTS (SELECT 1 FROM dbo.THANH_TOAN_DON_HANG WHERE MaTTDH=@TT AND TrangThai=N''Thất bại'')
        THROW 52000, N''Giao dịch không chuyển Thất bại.'', 1;
';
GO

EXEC #Ca N'[A4] sp_CapNhatThanhToan xác nhận Thành công thì đơn chuyển Đang xử lý', N'
    EXEC dbo.sp_DuyetSanPham @MaSP=@SP1, @KetQua=N''Đã chấp nhận'';
    EXEC dbo.sp_DangBanSanPham @MaSP=@SP1, @GiaDangBan=200000;
    DECLARE @CT dbo.ChiTietDonHangType, @DH INT;
    INSERT @CT VALUES (@SP1, 0);
    EXEC dbo.sp_TaoDonHang @MaKH=@MaKH, @MaNV=@MaNV, @ChiTiet=@CT, @MaDH=@DH OUTPUT;
    DECLARE @TT INT;
    EXEC dbo.sp_GhiNhanThanhToan @MaDH=@DH, @SoTien=200000, @PhuongThuc=N''Tiền mặt'',
         @TrangThai=N''Chờ xử lý'', @MaTTDH=@TT OUTPUT;
    EXEC dbo.sp_CapNhatThanhToan @MaTTDH=@TT, @TrangThai=N''Thành công'';
    IF NOT EXISTS (SELECT 1 FROM dbo.DON_HANG WHERE MaDH=@DH AND TrangThai=N''Đang xử lý'')
        THROW 52000, N''Đơn không chuyển Đang xử lý.'', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.SAN_PHAM WHERE MaSP=@SP1 AND TrangThaiBan=N''Đã bán'')
        THROW 52000, N''Sản phẩm không chuyển Đã bán.'', 1;
';
GO

EXEC #Ca N'[A4] Không cập nhật được giao dịch đã Thành công', N'
    EXEC dbo.sp_DuyetSanPham @MaSP=@SP1, @KetQua=N''Đã chấp nhận'';
    EXEC dbo.sp_DangBanSanPham @MaSP=@SP1, @GiaDangBan=200000;
    DECLARE @CT dbo.ChiTietDonHangType, @DH INT;
    INSERT @CT VALUES (@SP1, 0);
    EXEC dbo.sp_TaoDonHang @MaKH=@MaKH, @MaNV=@MaNV, @ChiTiet=@CT, @MaDH=@DH OUTPUT;
    DECLARE @TT INT;
    EXEC dbo.sp_GhiNhanThanhToan @MaDH=@DH, @SoTien=200000, @PhuongThuc=N''Tiền mặt'', @MaTTDH=@TT OUTPUT;
    EXEC dbo.sp_CapNhatThanhToan @MaTTDH=@TT, @TrangThai=N''Thất bại'';
', 52203;
GO

EXEC #Ca N'[A4] Xác nhận Thành công vượt giá trị đơn bị chặn', N'
    EXEC dbo.sp_DuyetSanPham @MaSP=@SP1, @KetQua=N''Đã chấp nhận'';
    EXEC dbo.sp_DangBanSanPham @MaSP=@SP1, @GiaDangBan=200000;
    DECLARE @CT dbo.ChiTietDonHangType, @DH INT;
    INSERT @CT VALUES (@SP1, 0);
    EXEC dbo.sp_TaoDonHang @MaKH=@MaKH, @MaNV=@MaNV, @ChiTiet=@CT, @MaDH=@DH OUTPUT;
    DECLARE @T1 INT, @T2 INT;
    EXEC dbo.sp_GhiNhanThanhToan @MaDH=@DH, @SoTien=150000, @PhuongThuc=N''Tiền mặt'', @MaTTDH=@T1 OUTPUT;
    EXEC dbo.sp_GhiNhanThanhToan @MaDH=@DH, @SoTien=100000, @PhuongThuc=N''Tiền mặt'',
         @TrangThai=N''Chờ xử lý'', @MaTTDH=@T2 OUTPUT;
    EXEC dbo.sp_CapNhatThanhToan @MaTTDH=@T2, @TrangThai=N''Thành công'';
', 52204;
GO

/* ============================================================
   NHÓM 4 — PHIẾU QUYẾT TOÁN RỖNG  (lỗi A6)
   ============================================================ */

EXEC #Ca N'[A6] Xoá chi tiết cuối cùng của phiếu quyết toán chờ chi bị chặn', N'
    DECLARE @DS dbo.DanhSachCTDHType, @PTT INT;
    INSERT @DS
    SELECT TOP (1) c.MaCTDH
    FROM dbo.CHI_TIET_DON_HANG c
    JOIN dbo.DON_HANG d ON d.MaDH = c.MaDH AND d.TrangThai = N''Hoàn tất''
    JOIN dbo.SAN_PHAM sp ON sp.MaSP = c.MaSP
    JOIN dbo.PHIEU_KY_GUI pk ON pk.MaPKG = sp.MaPKG
    WHERE NOT EXISTS (SELECT 1 FROM dbo.CHI_TIET_THANH_TOAN_KY_GUI x WHERE x.MaCTDH = c.MaCTDH)
    ORDER BY c.MaCTDH;
    IF NOT EXISTS (SELECT 1 FROM @DS)
        THROW 52000, N''Không còn sản phẩm chưa quyết toán để kiểm tra.'', 1;
    DECLARE @KH INT = (SELECT pk.MaKH FROM dbo.CHI_TIET_DON_HANG c
                       JOIN dbo.SAN_PHAM sp ON sp.MaSP = c.MaSP
                       JOIN dbo.PHIEU_KY_GUI pk ON pk.MaPKG = sp.MaPKG
                       WHERE c.MaCTDH = (SELECT TOP (1) MaCTDH FROM @DS));
    EXEC dbo.sp_LapPhieuQuyetToan @MaKH=@KH, @MaNV=@MaNV, @PhuongThuc=N''Tiền mặt'',
         @DanhSach=@DS, @MaPTTKG=@PTT OUTPUT;
    DELETE dbo.CHI_TIET_THANH_TOAN_KY_GUI WHERE MaPTTKG=@PTT;
', 50022;
GO

EXEC #Ca N'[A6] Xoá một chi tiết khi phiếu còn chi tiết khác vẫn được phép', N'
    DECLARE @DS dbo.DanhSachCTDHType, @PTT INT;
    INSERT @DS
    SELECT TOP (2) c.MaCTDH
    FROM dbo.CHI_TIET_DON_HANG c
    JOIN dbo.DON_HANG d ON d.MaDH = c.MaDH AND d.TrangThai = N''Hoàn tất''
    JOIN dbo.SAN_PHAM sp ON sp.MaSP = c.MaSP
    JOIN dbo.PHIEU_KY_GUI pk ON pk.MaPKG = sp.MaPKG
    WHERE NOT EXISTS (SELECT 1 FROM dbo.CHI_TIET_THANH_TOAN_KY_GUI x WHERE x.MaCTDH = c.MaCTDH)
      AND pk.MaKH = (SELECT TOP (1) pk2.MaKH
                     FROM dbo.CHI_TIET_DON_HANG c2
                     JOIN dbo.DON_HANG d2 ON d2.MaDH = c2.MaDH AND d2.TrangThai = N''Hoàn tất''
                     JOIN dbo.SAN_PHAM sp2 ON sp2.MaSP = c2.MaSP
                     JOIN dbo.PHIEU_KY_GUI pk2 ON pk2.MaPKG = sp2.MaPKG
                     WHERE NOT EXISTS (SELECT 1 FROM dbo.CHI_TIET_THANH_TOAN_KY_GUI x2 WHERE x2.MaCTDH = c2.MaCTDH)
                     GROUP BY pk2.MaKH HAVING COUNT(*) >= 2
                     ORDER BY pk2.MaKH)
    ORDER BY c.MaCTDH;
    IF (SELECT COUNT(*) FROM @DS) < 2
        THROW 52000, N''Cần một người ký gửi có ít nhất 2 sản phẩm chưa quyết toán.'', 1;
    DECLARE @KH2 INT = (SELECT pk.MaKH FROM dbo.CHI_TIET_DON_HANG c
                        JOIN dbo.SAN_PHAM sp ON sp.MaSP = c.MaSP
                        JOIN dbo.PHIEU_KY_GUI pk ON pk.MaPKG = sp.MaPKG
                        WHERE c.MaCTDH = (SELECT TOP (1) MaCTDH FROM @DS));
    EXEC dbo.sp_LapPhieuQuyetToan @MaKH=@KH2, @MaNV=@MaNV, @PhuongThuc=N''Tiền mặt'',
         @DanhSach=@DS, @MaPTTKG=@PTT OUTPUT;
    DELETE dbo.CHI_TIET_THANH_TOAN_KY_GUI
    WHERE MaPTTKG=@PTT AND MaCTDH = (SELECT TOP (1) MaCTDH FROM @DS);
';
GO

/* ============================================================
   NHÓM 5 — NGÀY THÁNG  (lỗi A7, A8)
   ============================================================ */

EXEC #Ca N'[A7] Lập đơn với NgayLap trước NgayDangBan bị chặn', N'
    EXEC dbo.sp_DuyetSanPham @MaSP=@SP1, @KetQua=N''Đã chấp nhận'';
    EXEC dbo.sp_DangBanSanPham @MaSP=@SP1, @GiaDangBan=200000;
    DECLARE @CT dbo.ChiTietDonHangType, @DH INT;
    INSERT @CT VALUES (@SP1, 0);
    EXEC dbo.sp_TaoDonHang @MaKH=@MaKH, @MaNV=@MaNV, @NgayLap=N''2020-01-01 09:00'',
         @HanThanhToan=N''2030-01-01 17:00'', @ChiTiet=@CT, @MaDH=@DH OUTPUT;
', 51312;
GO

EXEC #Ca N'[A7] Thu tiền với NgayTao trước NgayLap bị chặn', N'
    EXEC dbo.sp_DuyetSanPham @MaSP=@SP1, @KetQua=N''Đã chấp nhận'';
    EXEC dbo.sp_DangBanSanPham @MaSP=@SP1, @GiaDangBan=200000;
    DECLARE @CT dbo.ChiTietDonHangType, @DH INT;
    INSERT @CT VALUES (@SP1, 0);
    EXEC dbo.sp_TaoDonHang @MaKH=@MaKH, @MaNV=@MaNV, @ChiTiet=@CT, @MaDH=@DH OUTPUT;
    DECLARE @TT INT;
    EXEC dbo.sp_GhiNhanThanhToan @MaDH=@DH, @SoTien=200000, @PhuongThuc=N''Tiền mặt'',
         @NgayTao=N''2020-01-01 08:00'', @MaTTDH=@TT OUTPUT;
', 51407;
GO

EXEC #Ca N'[A8] Hạn thanh toán trước ngày lập (lập sau 17h, hạn hôm nay) bị chặn', N'
    EXEC dbo.sp_DuyetSanPham @MaSP=@SP1, @KetQua=N''Đã chấp nhận'';
    EXEC dbo.sp_DangBanSanPham @MaSP=@SP1, @GiaDangBan=200000;
    DECLARE @NgayLap DATETIME2(0), @Han DATETIME2(0);
    SET @NgayLap = DATEADD(hour, 18, CAST(CAST(SYSDATETIME() AS date) AS datetime2(0)));
    SET @Han = DATEADD(hour, 17, CAST(CAST(SYSDATETIME() AS date) AS datetime2(0)));
    DECLARE @CT dbo.ChiTietDonHangType, @DH INT;
    INSERT @CT VALUES (@SP1, 0);
    EXEC dbo.sp_TaoDonHang @MaKH=@MaKH, @MaNV=@MaNV,
         @NgayLap=@NgayLap, @HanThanhToan=@Han,
         @ChiTiet=@CT, @MaDH=@DH OUTPUT;
', 51304;
GO

EXEC #Ca N'[A8] Lập đơn hôm nay hạn 3 ngày sau vẫn bình thường', N'
    EXEC dbo.sp_DuyetSanPham @MaSP=@SP1, @KetQua=N''Đã chấp nhận'';
    EXEC dbo.sp_DangBanSanPham @MaSP=@SP1, @GiaDangBan=200000;
    DECLARE @Han2 DATETIME2(0) = DATEADD(day, 3, SYSDATETIME());
    DECLARE @CT dbo.ChiTietDonHangType, @DH INT;
    INSERT @CT VALUES (@SP1, 0);
    EXEC dbo.sp_TaoDonHang @MaKH=@MaKH, @MaNV=@MaNV,
         @HanThanhToan=@Han2, @ChiTiet=@CT, @MaDH=@DH OUTPUT;
    IF NOT EXISTS (SELECT 1 FROM dbo.DON_HANG WHERE MaDH=@DH AND TrangThai=N''Chờ thanh toán'')
        THROW 52000, N''Đơn không ở trạng thái Chờ thanh toán.'', 1;
';
GO

/* ============================================================
   NHÓM 6 — TRẢ HÀNG LÀ TRẠNG THÁI CUỐI  (lỗi A9, B4)
   ============================================================ */

EXEC #Ca N'[A9] Không đưa sản phẩm Đã trả lại trở về Đang bán (UPDATE trực tiếp)', N'
    EXEC dbo.sp_DuyetSanPham @MaSP=@SP1, @KetQua=N''Đã chấp nhận'';
    EXEC dbo.sp_DangBanSanPham @MaSP=@SP1, @GiaDangBan=300000;
    EXEC dbo.sp_TraHang @MaSP=@SP1;
    UPDATE dbo.SAN_PHAM SET TrangThaiBan = N''Đang bán'' WHERE MaSP=@SP1;
', 50020;
GO

EXEC #Ca N'[A9] Đăng bán lại sản phẩm Đã trả lại bị chặn', N'
    EXEC dbo.sp_DuyetSanPham @MaSP=@SP1, @KetQua=N''Đã chấp nhận'';
    EXEC dbo.sp_DangBanSanPham @MaSP=@SP1, @GiaDangBan=300000;
    EXEC dbo.sp_TraHang @MaSP=@SP1;
    EXEC dbo.sp_DangBanSanPham @MaSP=@SP1, @GiaDangBan=300000;
', 51203;
GO

/* ============================================================
   NHÓM 7 — KHÔNG ĐƯỢC ĐÁNH DẤU ĐÃ BÁN NGOÀI ĐƠN HÀNG  (lỗi B1)
   ============================================================ */

EXEC #Ca N'[B1] UPDATE trực tiếp Đang bán -> Đã bán (không có đơn) bị chặn', N'
    EXEC dbo.sp_DuyetSanPham @MaSP=@SP1, @KetQua=N''Đã chấp nhận'';
    EXEC dbo.sp_DangBanSanPham @MaSP=@SP1, @GiaDangBan=300000;
    UPDATE dbo.SAN_PHAM SET TrangThaiBan = N''Đã bán'' WHERE MaSP=@SP1;
', 50021;
GO

EXEC #Ca N'[B1] Đánh dấu Đã bán qua đơn hàng hợp lệ vẫn chạy đúng', N'
    EXEC dbo.sp_DuyetSanPham @MaSP=@SP1, @KetQua=N''Đã chấp nhận'';
    EXEC dbo.sp_DangBanSanPham @MaSP=@SP1, @GiaDangBan=300000;
    DECLARE @CT dbo.ChiTietDonHangType, @DH INT;
    INSERT @CT VALUES (@SP1, 0);
    EXEC dbo.sp_TaoDonHang @MaKH=@MaKH, @MaNV=@MaNV, @ChiTiet=@CT, @MaDH=@DH OUTPUT;
    DECLARE @TT INT;
    EXEC dbo.sp_GhiNhanThanhToan @MaDH=@DH, @SoTien=300000, @PhuongThuc=N''Tiền mặt'', @MaTTDH=@TT OUTPUT;
    IF NOT EXISTS (SELECT 1 FROM dbo.SAN_PHAM WHERE MaSP=@SP1 AND TrangThaiBan=N''Đã bán'')
        THROW 52000, N''Sản phẩm không chuyển Đã bán.'', 1;
';
GO

/* ============================================================
   NHÓM 8 — BIÊN SỐ TIỀN VÀ LÀM TRÒN HOA HỒNG
   ============================================================ */

EXEC #Ca N'[Tiền] Thu đúng bằng tổng tiền: đơn chuyển Đang xử lý', N'
    EXEC dbo.sp_DuyetSanPham @MaSP=@SP1, @KetQua=N''Đã chấp nhận'';
    EXEC dbo.sp_DangBanSanPham @MaSP=@SP1, @GiaDangBan=250000;
    DECLARE @CT dbo.ChiTietDonHangType, @DH INT;
    INSERT @CT VALUES (@SP1, 0);
    EXEC dbo.sp_TaoDonHang @MaKH=@MaKH, @MaNV=@MaNV, @ChiTiet=@CT, @MaDH=@DH OUTPUT;
    DECLARE @TT INT;
    EXEC dbo.sp_GhiNhanThanhToan @MaDH=@DH, @SoTien=250000, @PhuongThuc=N''Tiền mặt'', @MaTTDH=@TT OUTPUT;
    IF NOT EXISTS (SELECT 1 FROM dbo.DON_HANG WHERE MaDH=@DH AND TrangThai=N''Đang xử lý'')
        THROW 52000, N''Đơn không chuyển Đang xử lý khi thu đủ.'', 1;
';
GO

EXEC #Ca N'[Tiền] Thu thiếu 1 đồng: đơn vẫn Chờ thanh toán', N'
    EXEC dbo.sp_DuyetSanPham @MaSP=@SP1, @KetQua=N''Đã chấp nhận'';
    EXEC dbo.sp_DangBanSanPham @MaSP=@SP1, @GiaDangBan=250000;
    DECLARE @CT dbo.ChiTietDonHangType, @DH INT;
    INSERT @CT VALUES (@SP1, 0);
    EXEC dbo.sp_TaoDonHang @MaKH=@MaKH, @MaNV=@MaNV, @ChiTiet=@CT, @MaDH=@DH OUTPUT;
    DECLARE @TT INT;
    EXEC dbo.sp_GhiNhanThanhToan @MaDH=@DH, @SoTien=249999, @PhuongThuc=N''Tiền mặt'', @MaTTDH=@TT OUTPUT;
    IF NOT EXISTS (SELECT 1 FROM dbo.DON_HANG WHERE MaDH=@DH AND TrangThai=N''Chờ thanh toán'')
        THROW 52000, N''Đơn không giữ Chờ thanh toán khi còn thiếu tiền.'', 1;
';
GO

EXEC #Ca N'[Tiền] Hai giao dịch cộng lại vừa đủ: đơn chuyển Đang xử lý', N'
    EXEC dbo.sp_DuyetSanPham @MaSP=@SP1, @KetQua=N''Đã chấp nhận'';
    EXEC dbo.sp_DangBanSanPham @MaSP=@SP1, @GiaDangBan=400000;
    DECLARE @CT dbo.ChiTietDonHangType, @DH INT;
    INSERT @CT VALUES (@SP1, 0);
    EXEC dbo.sp_TaoDonHang @MaKH=@MaKH, @MaNV=@MaNV, @ChiTiet=@CT, @MaDH=@DH OUTPUT;
    DECLARE @T1 INT, @T2 INT;
    EXEC dbo.sp_GhiNhanThanhToan @MaDH=@DH, @SoTien=250000, @PhuongThuc=N''Tiền mặt'', @MaTTDH=@T1 OUTPUT;
    EXEC dbo.sp_GhiNhanThanhToan @MaDH=@DH, @SoTien=150000, @PhuongThuc=N''Chuyển khoản'', @MaTTDH=@T2 OUTPUT;
    IF NOT EXISTS (SELECT 1 FROM dbo.DON_HANG WHERE MaDH=@DH AND TrangThai=N''Đang xử lý'')
        THROW 52000, N''Đơn không chuyển Đang xử lý sau hai giao dịch.'', 1;
';
GO

EXEC #Ca N'[Tiền] Thu vượt giá trị đơn: coi như đủ, chênh lệch dương', N'
    EXEC dbo.sp_DuyetSanPham @MaSP=@SP1, @KetQua=N''Đã chấp nhận'';
    EXEC dbo.sp_DangBanSanPham @MaSP=@SP1, @GiaDangBan=100000;
    DECLARE @CT dbo.ChiTietDonHangType, @DH INT;
    INSERT @CT VALUES (@SP1, 0);
    EXEC dbo.sp_TaoDonHang @MaKH=@MaKH, @MaNV=@MaNV, @ChiTiet=@CT, @MaDH=@DH OUTPUT;
    DECLARE @TT INT;
    EXEC dbo.sp_GhiNhanThanhToan @MaDH=@DH, @SoTien=1000000, @PhuongThuc=N''Tiền mặt'', @MaTTDH=@TT OUTPUT;
    IF NOT EXISTS (SELECT 1 FROM dbo.DON_HANG WHERE MaDH=@DH AND TrangThai=N''Đang xử lý'')
        THROW 52000, N''Đơn không chuyển Đang xử lý khi trả thừa.'', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.vw_DoiSoat_ThanhToan WHERE MaDH=@DH AND ChenhLech=900000 AND KetQuaDoiSoat=N''Trả thừa'')
        THROW 52000, N''Đối soát không ghi nhận trả thừa 900.000.'', 1;
';
GO

EXEC #Ca N'[Tiền] Giá đăng bán 1 đồng (biên dưới) được phép', N'
    EXEC dbo.sp_DuyetSanPham @MaSP=@SP1, @KetQua=N''Đã chấp nhận'';
    EXEC dbo.sp_DangBanSanPham @MaSP=@SP1, @GiaDangBan=1;
    IF NOT EXISTS (SELECT 1 FROM dbo.SAN_PHAM WHERE MaSP=@SP1 AND GiaDangBan=1 AND TrangThaiBan=N''Đang bán'')
        THROW 52000, N''Không lưu được giá 1 đồng.'', 1;
';
GO

EXEC #Ca N'[Tiền] Giá đăng bán 0 bị chặn', N'
    EXEC dbo.sp_DuyetSanPham @MaSP=@SP1, @KetQua=N''Đã chấp nhận'';
    EXEC dbo.sp_DangBanSanPham @MaSP=@SP1, @GiaDangBan=0;
', 51204;
GO

/* ============================================================
   NHÓM 9 — HOA HỒNG 20% VÀ LÀM TRÒN
   ============================================================ */

EXEC #Ca N'[Hoa hồng] Làm tròn biên: 5 -> hh 1/thực nhận 4; 3 -> hh 1/thực nhận 2; 2 -> hh 0/thực nhận 2', N'
    /* Bảng tạm mô phỏng đúng biểu thức computed của CHI_TIET_THANH_TOAN_KY_GUI */
    DECLARE @M TABLE (Gia DECIMAL(12,0), HH DECIMAL(12,0), TN DECIMAL(12,0));
    INSERT @M (Gia)
    VALUES (5), (3), (2), (1), (7), (10), (999999);
    UPDATE @M SET
        HH = CAST(ROUND(Gia * 0.20, 0) AS DECIMAL(12,0)),
        TN = CAST(Gia - ROUND(Gia * 0.20, 0) AS DECIMAL(12,0));

    IF EXISTS (SELECT 1 FROM @M WHERE Gia = 5 AND (HH <> 1 OR TN <> 4))
        THROW 52000, N''Sai làm tròn tại giá 5: cần hh=1, thực nhận=4.'', 1;
    IF EXISTS (SELECT 1 FROM @M WHERE Gia = 3 AND (HH <> 1 OR TN <> 2))
        THROW 52000, N''Sai làm tròn tại giá 3: cần hh=1, thực nhận=2.'', 1;
    IF EXISTS (SELECT 1 FROM @M WHERE Gia = 2 AND (HH <> 0 OR TN <> 2))
        THROW 52000, N''Sai làm tròn tại giá 2: cần hh=0, thực nhận=2.'', 1;
    IF EXISTS (SELECT 1 FROM @M WHERE Gia = 1 AND (HH <> 0 OR TN <> 1))
        THROW 52000, N''Sai làm tròn tại giá 1.'', 1;
    IF EXISTS (SELECT 1 FROM @M WHERE HH + TN <> Gia)
        THROW 52000, N''Hoa hồng + thực nhận không bằng giá bán.'', 1;
    IF EXISTS (SELECT 1 FROM @M WHERE TN < 0 OR HH < 0)
        THROW 52000, N''Có giá trị âm sau khi tính.'', 1;
';
GO

EXEC #Ca N'[Hoa hồng] Công thức hoa hồng khớp ở mọi bảng có dùng', N'
    IF EXISTS
    (
        SELECT 1 FROM dbo.CHI_TIET_THANH_TOAN_KY_GUI
        WHERE TienHoaHong <> CAST(ROUND(GiaBanTinhToan * 0.20, 0) AS DECIMAL(12,0))
           OR TienThucNhan <> GiaBanTinhToan - CAST(ROUND(GiaBanTinhToan * 0.20, 0) AS DECIMAL(12,0))
    )
        THROW 52000, N''Bảng chi tiết quyết toán lệch công thức 20%.'', 1;
    IF EXISTS
    (
        SELECT 1 FROM dbo.vw_QuyetToan_SanPham
        WHERE TienHoaHong <> CAST(ROUND(GiaBan * 0.20, 0) AS DECIMAL(12,0))
           OR TienThucNhan <> GiaBan - CAST(ROUND(GiaBan * 0.20, 0) AS DECIMAL(12,0))
    )
        THROW 52000, N''View quyết toán lệch công thức 20%.'', 1;
    IF EXISTS
    (
        SELECT 1 FROM dbo.vw_DoanhThu_TheoThang
        WHERE TienHoaHong + TienTraNguoiKyGui <> DoanhThu
    )
        THROW 52000, N''Báo cáo doanh thu không cân: hoa hồng + trả ký gửi <> doanh thu.'', 1;
';
GO

EXEC #Ca N'[Trần giá] Giá đăng bán đúng 500.000.000 được phép (biên trên)', N'
    EXEC dbo.sp_DuyetSanPham @MaSP=@SP1, @KetQua=N''Đã chấp nhận'';
    EXEC dbo.sp_DangBanSanPham @MaSP=@SP1, @GiaDangBan=500000000;
    IF NOT EXISTS (SELECT 1 FROM dbo.SAN_PHAM WHERE MaSP=@SP1 AND GiaDangBan=500000000)
        THROW 52000, N''Không lưu được giá đúng bằng trần.'', 1;
';
GO

EXEC #Ca N'[Trần giá] Giá đăng bán 500.000.001 bị chặn', N'
    EXEC dbo.sp_DuyetSanPham @MaSP=@SP1, @KetQua=N''Đã chấp nhận'';
    EXEC dbo.sp_DangBanSanPham @MaSP=@SP1, @GiaDangBan=500000001;
', 51205;
GO

EXEC #Ca N'[Trần giá] Giá đăng bán 600.000.000 bị chặn (không bị cắt câm thành 0)', N'
    EXEC dbo.sp_DuyetSanPham @MaSP=@SP1, @KetQua=N''Đã chấp nhận'';
    EXEC dbo.sp_DangBanSanPham @MaSP=@SP1, @GiaDangBan=600000000;
', 51205;
GO

EXEC #Ca N'[Trần giá] Giá đề xuất 500.000.001 khi tiếp nhận bị chặn', N'
    DECLARE @SPX dbo.SanPhamKyGuiType, @Id INT;
    INSERT @SPX (MaDM, TenSP, TinhTrang, GiaDeXuat, TrangThaiTiepNhan)
    VALUES (@MaDM, N''Món giá quá trần'', N''Còn tốt'', 500000001, N''Chờ xử lý'');
    EXEC dbo.sp_TiepNhanPhieuKyGui @MaKH=@MaKH, @MaNV=@MaNV, @SanPham=@SPX, @MaPKG=@Id OUTPUT;
', 51012;
GO

EXEC #Ca N'[Trần giá] Giá đề xuất đúng 500.000.000 khi tiếp nhận được phép', N'
    DECLARE @SPX dbo.SanPhamKyGuiType, @Id INT;
    INSERT @SPX (MaDM, TenSP, TinhTrang, GiaDeXuat, TrangThaiTiepNhan)
    VALUES (@MaDM, N''Món đúng trần'', N''Còn tốt'', 500000000, N''Chờ xử lý'');
    EXEC dbo.sp_TiepNhanPhieuKyGui @MaKH=@MaKH, @MaNV=@MaNV, @SanPham=@SPX, @MaPKG=@Id OUTPUT;
    IF NOT EXISTS (SELECT 1 FROM dbo.SAN_PHAM WHERE MaPKG=@Id AND GiaDeXuat=500000000)
        THROW 52000, N''Không lưu được giá đề xuất đúng trần.'', 1;
';
GO

EXEC #Ca N'[Trần giá] INSERT trực tiếp giá vượt trần bị CHECK của bảng chặn', N'
    INSERT dbo.SAN_PHAM (MaPKG, MaDM, TenSP, TinhTrang, GiaDeXuat, TrangThaiTiepNhan)
    VALUES (1, (SELECT TOP(1) MaDM FROM dbo.DANH_MUC), N''Vượt trần'', N''Còn tốt'', 600000000, N''Chờ xử lý'');
', 547;
GO

/* ============================================================
   NHÓM 12 — SỐ ĐIỆN THOẠI ĐÃ CHUẨN HOÁ
   ============================================================ */

EXEC #Ca N'[SĐT] Không còn số điện thoại chứa dấu cách/chấm/gạch sau chuẩn hoá', N'
    IF EXISTS (SELECT 1 FROM dbo.KHACH_HANG WHERE SoDienThoai LIKE N''%[ .-]%'')
        THROW 52000, N''Còn số điện thoại khách hàng chưa chuẩn hoá.'', 1;
    IF EXISTS (SELECT 1 FROM dbo.NHAN_VIEN WHERE SoDienThoai LIKE N''%[ .-]%'')
        THROW 52000, N''Còn số điện thoại nhân viên chưa chuẩn hoá.'', 1;
';
GO

/* SĐT đã được siết ở tầng CSDL: mọi dạng chưa chuẩn hoá đều bị chặn ngay khi chèn,
   nên không còn đường tạo hai hồ sơ cho cùng một số người bằng cách gõ khác nhau. */

EXEC #Ca N'[SĐT] INSERT trực tiếp số có dấu cách bị CHECK chặn', N'
    INSERT dbo.KHACH_HANG (HoTen, SoDienThoai) VALUES (N''Khách thử biên'', N''0901 000 001'');
', 547;
GO

EXEC #Ca N'[SĐT] INSERT trực tiếp số có dấu gạch nối bị CHECK chặn', N'
    INSERT dbo.KHACH_HANG (HoTen, SoDienThoai) VALUES (N''Khách thử biên'', N''0901-000-001'');
', 547;
GO

EXEC #Ca N'[SĐT] INSERT trực tiếp số có nhiều dấu + bị CHECK chặn', N'
    INSERT dbo.KHACH_HANG (HoTen, SoDienThoai) VALUES (N''Khách thử biên'', N''++8490123456'');
', 547;
GO

EXEC #Ca N'[SĐT] Dạng chuẩn (chỉ số, hoặc + và số) vẫn được chấp nhận', N'
    INSERT dbo.KHACH_HANG (HoTen, SoDienThoai) VALUES (N''Khách thử biên số'', N''0909999001'');
    INSERT dbo.KHACH_HANG (HoTen, SoDienThoai) VALUES (N''Khách thử biên +'', N''+84909999001'');
';
GO

EXEC #Ca N'[SĐT] Nhân viên có SĐT dạng chuẩn và SĐT NULL đều được phép', N'
    DECLARE @Co INT = (SELECT COUNT(*) FROM dbo.NHAN_VIEN
                       WHERE SoDienThoai IS NULL
                          OR SoDienThoai NOT LIKE N''%[^0-9]%''
                          OR (SoDienThoai LIKE N''+%''
                              AND SUBSTRING(SoDienThoai, 2, 20) NOT LIKE N''%[^0-9]%''));
    IF @Co = 0
        THROW 52000, N''Không có nhân viên nào thỏa quy tắc SĐT.'', 1;
';
GO

EXEC #Ca N'[SĐT] INSERT trực tiếp SĐT nhân viên có dấu cách bị CHECK chặn', N'
    INSERT dbo.NHAN_VIEN (HoTen, SoDienThoai, ChucVu, TrangThai)
    VALUES (N''NV thử biên'', N''090 123 4567'', N''Nhân viên'', N''Đang làm việc'');
', 547;
GO

/* ============================================================
   NHÓM 11 — TRẠNG THÁI PHIẾU KÝ GỬI NHẤT QUÁN
   ============================================================ */

EXEC #Ca N'[Phiếu] Trả hết sản phẩm đang bán thì phiếu chuyển Đã hoàn tất', N'
    EXEC dbo.sp_DuyetSanPham @MaSP=@SP1, @KetQua=N''Đã chấp nhận'';
    EXEC dbo.sp_DuyetSanPham @MaSP=@SP2, @KetQua=N''Từ chối'';
    EXEC dbo.sp_DuyetSanPham @MaSP=@SP3, @KetQua=N''Từ chối'';
    EXEC dbo.sp_DangBanSanPham @MaSP=@SP1, @GiaDangBan=300000;
    EXEC dbo.sp_TraHang @MaSP=@SP1;
    IF NOT EXISTS (SELECT 1 FROM dbo.PHIEU_KY_GUI WHERE MaPKG=@MaPKG AND TrangThai=N''Đã hoàn tất'')
        THROW 52000, N''Phiếu không chuyển Đã hoàn tất sau khi trả hết.'', 1;
';
GO

EXEC #Ca N'[Phiếu] Từ chối món đang trong đơn còn hiệu lực bị chặn', N'
    EXEC dbo.sp_DuyetSanPham @MaSP=@SP1, @KetQua=N''Đã chấp nhận'';
    EXEC dbo.sp_DangBanSanPham @MaSP=@SP1, @GiaDangBan=300000;
    DECLARE @CT dbo.ChiTietDonHangType, @DH INT;
    INSERT @CT VALUES (@SP1, 0);
    EXEC dbo.sp_TaoDonHang @MaKH=@MaKH, @MaNV=@MaNV, @ChiTiet=@CT, @MaDH=@DH OUTPUT;
    EXEC dbo.sp_DuyetSanPham @MaSP=@SP1, @KetQua=N''Từ chối'';
', 51102;
GO

EXEC #Ca N'[Phiếu] Nhân viên đã nghỉ không lập được phiếu ký gửi', N'
    DECLARE @Nghi INT = (SELECT TOP (1) MaNV FROM dbo.NHAN_VIEN WHERE TrangThai = N''Đã nghỉ'' ORDER BY MaNV);
    IF @Nghi IS NULL
        THROW 52000, N''Dữ liệu mẫu không có nhân viên đã nghỉ.'', 1;
    DECLARE @SPX dbo.SanPhamKyGuiType, @Id INT;
    INSERT @SPX (MaDM, TenSP, TinhTrang, TrangThaiTiepNhan)
    VALUES (@MaDM, N''Món thử'', N''Còn tốt'', N''Chờ xử lý'');
    EXEC dbo.sp_TiepNhanPhieuKyGui @MaKH=@MaKH, @MaNV=@Nghi, @SanPham=@SPX, @MaPKG=@Id OUTPUT;
', 51002;
GO

/* ============================================================
   KẾT QUẢ
   ============================================================ */
SELECT STT, MoTa, KetQua, GhiChu FROM #KQ ORDER BY STT;
GO

SELECT COUNT(*) AS TongSo,
       SUM(CASE WHEN KetQua = 'PASS' THEN 1 ELSE 0 END) AS Dat,
       SUM(CASE WHEN KetQua = 'FAIL' THEN 1 ELSE 0 END) AS Hong
FROM #KQ;
GO

IF EXISTS (SELECT 1 FROM #KQ WHERE KetQua = 'FAIL')
    THROW 52001, N'Có kiểm thử biên không đạt. Xem bảng kết quả phía trên.', 1;
GO

DROP TABLE #KQ;
GO
PRINT N'Toàn bộ kiểm thử biên đạt.';
GO

