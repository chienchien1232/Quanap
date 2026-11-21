USE [QuanLyKyGuiThoiTrang];
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
GO
-- Mỗi ca tạo một phiếu/món riêng trong transaction rồi rollback.
-- Không sửa hồ sơ nghiệp vụ đang có; mã IDENTITY đã cấp có thể để lại khoảng trống.
CREATE TABLE #KetQua (STT INT IDENTITY, MoTa NVARCHAR(250), KetQua VARCHAR(4), ChiTiet NVARCHAR(2000));
GO
CREATE PROCEDURE #KiemTra
    @MoTa NVARCHAR(250), @Lenh NVARCHAR(MAX), @LoiMongDoi INT = 0
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Setup NVARCHAR(MAX) = N'USE [QuanLyKyGuiThoiTrang];
DECLARE @MaKH INT = (SELECT TOP (1) MaKH FROM dbo.KHACH_HANG ORDER BY MaKH);
DECLARE @MaNV INT = (SELECT TOP (1) MaNV FROM dbo.NHAN_VIEN WHERE TrangThai=N''Đang làm việc'' ORDER BY MaNV);
DECLARE @MaDM INT = (SELECT TOP (1) MaDM FROM dbo.DANH_MUC ORDER BY MaDM);
DECLARE @MaPKG INT, @SP1 INT, @SP2 INT;
IF @MaKH IS NULL OR @MaNV IS NULL OR @MaDM IS NULL
    THROW 52000,N''Cần khách hàng, nhân viên đang làm việc và danh mục để kiểm tra.'',1;
DECLARE @SanPham dbo.SanPhamKyGuiType;
INSERT @SanPham (MaDM,TenSP,TinhTrang,GiaDeXuat,TrangThaiTiepNhan)
VALUES (@MaDM,N''Món thử luồng A'',N''Còn tốt'',200000,N''Chờ xử lý''),
       (@MaDM,N''Món thử luồng B'',N''Còn tốt'',300000,N''Chờ xử lý'');
EXEC dbo.sp_TiepNhanPhieuKyGui @MaKH=@MaKH,@MaNV=@MaNV,@SanPham=@SanPham,@MaPKG=@MaPKG OUTPUT;
SELECT @SP1=MIN(MaSP),@SP2=MAX(MaSP) FROM dbo.SAN_PHAM WHERE MaPKG=@MaPKG;';
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @Sql NVARCHAR(MAX) = @Setup + CHAR(13) + CHAR(10) + @Lenh;
        EXEC sys.sp_executesql @Sql;
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        INSERT #KetQua VALUES (@MoTa, CASE WHEN @LoiMongDoi = 0 THEN 'PASS' ELSE 'FAIL' END,
            CASE WHEN @LoiMongDoi = 0 THEN N'Đúng kết quả và trạng thái.' ELSE N'Không phát sinh lỗi cần chặn.' END);
    END TRY
    BEGIN CATCH
        DECLARE @Loi INT = ERROR_NUMBER(), @ThongBao NVARCHAR(2000) = ERROR_MESSAGE();
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        INSERT #KetQua VALUES (@MoTa, CASE WHEN @Loi = @LoiMongDoi THEN 'PASS' ELSE 'FAIL' END,
            CONCAT(@Loi, N': ', @ThongBao));
    END CATCH;
END;
GO
EXEC #KiemTra N'Phiếu mới Đang xử lý; mọi món Chờ xử lý, chưa có giá/trạng thái bán', N'
    IF NOT EXISTS (SELECT 1 FROM dbo.PHIEU_KY_GUI WHERE MaPKG=@MaPKG AND TrangThai=N''Đang xử lý'')
        THROW 52000,N''Sai trạng thái phiếu mới.'',1;
    IF (SELECT COUNT(*) FROM dbo.SAN_PHAM WHERE MaPKG=@MaPKG) <> 2
       OR EXISTS (SELECT 1 FROM dbo.SAN_PHAM WHERE MaPKG=@MaPKG AND
            (TrangThaiTiepNhan<>N''Chờ xử lý'' OR GiaDangBan IS NOT NULL OR TrangThaiBan IS NOT NULL OR NgayDangBan IS NOT NULL))
        THROW 52000,N''Sản phẩm bị duyệt hoặc đăng bán sớm.'',1;';
GO
EXEC #KiemTra N'Không cho chấp nhận ngay khi lập phiếu', N'
    DECLARE @SP dbo.SanPhamKyGuiType, @Id INT;
    INSERT @SP (MaDM,TenSP,TinhTrang,TrangThaiTiepNhan) VALUES (@MaDM,N''Thử'',N''Tốt'',N''Đã chấp nhận'');
    EXEC dbo.sp_TiepNhanPhieuKyGui @MaKH=@MaKH,@MaNV=@MaNV,@SanPham=@SP,@MaPKG=@Id OUTPUT;', 51006;
GO
EXEC #KiemTra N'Không cho nhập giá bán khi tiếp nhận', N'
    DECLARE @SP dbo.SanPhamKyGuiType, @Id INT;
    INSERT @SP (MaDM,TenSP,TinhTrang,GiaDangBan,TrangThaiTiepNhan) VALUES (@MaDM,N''Thử'',N''Tốt'',100000,N''Chờ xử lý'');
    EXEC dbo.sp_TiepNhanPhieuKyGui @MaKH=@MaKH,@MaNV=@MaNV,@SanPham=@SP,@MaPKG=@Id OUTPUT;', 51011;
GO
EXEC #KiemTra N'Phiếu không có món bị chặn', N'
    DECLARE @SP dbo.SanPhamKyGuiType, @Id INT;
    EXEC dbo.sp_TiepNhanPhieuKyGui @MaKH=@MaKH,@MaNV=@MaNV,@SanPham=@SP,@MaPKG=@Id OUTPUT;', 51003;
GO
EXEC #KiemTra N'Chấp nhận không cần giá; còn món chờ thì phiếu vẫn Đang xử lý', N'
    EXEC dbo.sp_DuyetSanPham @MaSP=@SP1,@KetQua=N''Đã chấp nhận'';
    IF NOT EXISTS (SELECT 1 FROM dbo.SAN_PHAM WHERE MaSP=@SP1 AND TrangThaiTiepNhan=N''Đã chấp nhận''
        AND TrangThaiBan=N''Chưa đăng bán'' AND GiaDangBan IS NULL AND NgayDangBan IS NULL)
        THROW 52000,N''Duyệt đã bị gộp với đăng bán.'',1;
    IF NOT EXISTS (SELECT 1 FROM dbo.PHIEU_KY_GUI WHERE MaPKG=@MaPKG AND TrangThai=N''Đang xử lý'')
        THROW 52000,N''Phiếu kết thúc xét duyệt quá sớm.'',1;';
GO
EXEC #KiemTra N'Xét hết có món nhận và món từ chối: phiếu Đang ký gửi', N'
    EXEC dbo.sp_DuyetSanPham @MaSP=@SP1,@KetQua=N''Đã chấp nhận'';
    EXEC dbo.sp_DuyetSanPham @MaSP=@SP2,@KetQua=N''Từ chối'';
    IF NOT EXISTS (SELECT 1 FROM dbo.PHIEU_KY_GUI WHERE MaPKG=@MaPKG AND TrangThai=N''Đang ký gửi'')
        THROW 52000,N''Sai trạng thái phiếu duyệt hỗn hợp.'',1;
    IF NOT EXISTS (SELECT 1 FROM dbo.SAN_PHAM WHERE MaSP=@SP2 AND TrangThaiTiepNhan=N''Từ chối''
        AND TrangThaiBan IS NULL AND GiaDangBan IS NULL AND NgayDangBan IS NULL)
        THROW 52000,N''Không giữ đúng hồ sơ món từ chối.'',1;';
GO
EXEC #KiemTra N'Tất cả món bị từ chối: phiếu Đã hủy, vẫn còn sản phẩm lịch sử', N'
    EXEC dbo.sp_DuyetSanPham @MaSP=@SP1,@KetQua=N''Từ chối'';
    EXEC dbo.sp_DuyetSanPham @MaSP=@SP2,@KetQua=N''Từ chối'';
    IF NOT EXISTS (SELECT 1 FROM dbo.PHIEU_KY_GUI WHERE MaPKG=@MaPKG AND TrangThai=N''Đã hủy'')
       OR (SELECT COUNT(*) FROM dbo.SAN_PHAM WHERE MaPKG=@MaPKG)<>2
        THROW 52000,N''Mất lịch sử hoặc sai trạng thái phiếu bị từ chối.'',1;';
GO
EXEC #KiemTra N'Không được duyệt lại món đã chấp nhận', N'
    EXEC dbo.sp_DuyetSanPham @MaSP=@SP1,@KetQua=N''Đã chấp nhận'';
    EXEC dbo.sp_DuyetSanPham @MaSP=@SP1,@KetQua=N''Từ chối'';', 51102;
GO
EXEC #KiemTra N'Không được duyệt lại món đã từ chối', N'
    EXEC dbo.sp_DuyetSanPham @MaSP=@SP1,@KetQua=N''Từ chối'';
    EXEC dbo.sp_DuyetSanPham @MaSP=@SP1,@KetQua=N''Đã chấp nhận'';', 51102;
GO
EXEC #KiemTra N'Không nhập giá trong thao tác duyệt', N'
    EXEC dbo.sp_DuyetSanPham @MaSP=@SP1,@KetQua=N''Đã chấp nhận'',@GiaDangBan=100000;', 51104;
GO
EXEC #KiemTra N'Chặn kết quả duyệt ngoài miền', N'
    EXEC dbo.sp_DuyetSanPham @MaSP=@SP1,@KetQua=N''Không hợp lệ'';', 51103;
GO
EXEC #KiemTra N'Không đăng bán món đang chờ xét duyệt', N'
    EXEC dbo.sp_DangBanSanPham @MaSP=@SP1,@GiaDangBan=100000;', 51202;
GO
EXEC #KiemTra N'Không đăng bán món bị từ chối', N'
    EXEC dbo.sp_DuyetSanPham @MaSP=@SP1,@KetQua=N''Từ chối'';
    EXEC dbo.sp_DangBanSanPham @MaSP=@SP1,@GiaDangBan=100000;', 51202;
GO
EXEC #KiemTra N'Chưa chốt giá thì chưa được đăng bán', N'
    EXEC dbo.sp_DuyetSanPham @MaSP=@SP1,@KetQua=N''Đã chấp nhận'';
    EXEC dbo.sp_DangBanSanPham @MaSP=@SP1;', 51204;
GO
EXEC #KiemTra N'Giá đăng bán 0 bị chặn', N'
    EXEC dbo.sp_DuyetSanPham @MaSP=@SP1,@KetQua=N''Đã chấp nhận'';
    EXEC dbo.sp_DangBanSanPham @MaSP=@SP1,@GiaDangBan=0;', 51204;
GO
EXEC #KiemTra N'Được chấp nhận rồi chốt giá và đăng bán; không đổi giá đề xuất', N'
    EXEC dbo.sp_DuyetSanPham @MaSP=@SP1,@KetQua=N''Đã chấp nhận'';
    EXEC dbo.sp_DangBanSanPham @MaSP=@SP1,@GiaDangBan=180000;
    IF NOT EXISTS (SELECT 1 FROM dbo.SAN_PHAM WHERE MaSP=@SP1 AND TrangThaiBan=N''Đang bán''
        AND GiaDangBan=180000 AND GiaDeXuat=200000 AND NgayDangBan IS NOT NULL)
        THROW 52000,N''Sai thông tin đăng bán.'',1;
    IF NOT EXISTS (SELECT 1 FROM dbo.PHIEU_KY_GUI WHERE MaPKG=@MaPKG AND TrangThai=N''Đang xử lý'')
        THROW 52000,N''Phải theo dõi riêng món chưa xét duyệt trong phiếu.'',1;';
GO
EXEC #KiemTra N'Chấp nhận nhưng chưa đăng bán thì chưa được mua', N'
    EXEC dbo.sp_DuyetSanPham @MaSP=@SP1,@KetQua=N''Đã chấp nhận'';
    DECLARE @CT dbo.ChiTietDonHangType, @DH INT;
    INSERT @CT VALUES (@SP1,0);
    EXEC dbo.sp_TaoDonHang @MaKH=@MaKH,@MaNV=@MaNV,@ChiTiet=@CT,@MaDH=@DH OUTPUT;', 51308;
GO
EXEC #KiemTra N'Đăng bán rồi mới lập đơn và giữ đúng món', N'
    EXEC dbo.sp_DuyetSanPham @MaSP=@SP1,@KetQua=N''Đã chấp nhận'';
    EXEC dbo.sp_DangBanSanPham @MaSP=@SP1,@GiaDangBan=180000;
    DECLARE @CT dbo.ChiTietDonHangType, @DH INT;
    INSERT @CT VALUES (@SP1,0);
    EXEC dbo.sp_TaoDonHang @MaKH=@MaKH,@MaNV=@MaNV,@ChiTiet=@CT,@MaDH=@DH OUTPUT;
    IF NOT EXISTS (SELECT 1 FROM dbo.SAN_PHAM WHERE MaSP=@SP1 AND TrangThaiBan=N''Đang giữ'')
       OR NOT EXISTS (SELECT 1 FROM dbo.CHI_TIET_DON_HANG WHERE MaDH=@DH AND MaSP=@SP1)
        THROW 52000,N''Đơn không giữ đúng sản phẩm đã đăng bán.'',1;';
GO
EXEC #KiemTra N'Đang giữ không được đổi giá hay đăng bán lại', N'
    EXEC dbo.sp_DuyetSanPham @MaSP=@SP1,@KetQua=N''Đã chấp nhận'';
    EXEC dbo.sp_DangBanSanPham @MaSP=@SP1,@GiaDangBan=180000;
    DECLARE @CT dbo.ChiTietDonHangType, @DH INT;
    INSERT @CT VALUES (@SP1,0);
    EXEC dbo.sp_TaoDonHang @MaKH=@MaKH,@MaNV=@MaNV,@ChiTiet=@CT,@MaDH=@DH OUTPUT;
    EXEC dbo.sp_DangBanSanPham @MaSP=@SP1,@GiaDangBan=190000;', 51203;
GO
SELECT STT, MoTa, KetQua, ChiTiet FROM #KetQua ORDER BY STT;
SELECT COUNT(*) AS TongSo, SUM(CASE WHEN KetQua='PASS' THEN 1 ELSE 0 END) AS Dat FROM #KetQua;
IF EXISTS (SELECT 1 FROM #KetQua WHERE KetQua='FAIL')
    THROW 52001, N'Có kiểm tra luồng ký gửi không đạt. Xem bảng kết quả.', 1;
GO

