USE [QuanLyKyGuiThoiTrang];
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
-- Nâng cấp luồng tiếp nhận / xét duyệt / đăng bán. Không xóa dữ liệu, không đổi kiểu bảng.
SET XACT_ABORT ON;
BEGIN TRANSACTION;
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_SAN_PHAM_ChuaDuyetKhongGia' AND parent_object_id = OBJECT_ID(N'dbo.SAN_PHAM'))
    ALTER TABLE dbo.SAN_PHAM WITH CHECK ADD CONSTRAINT CK_SAN_PHAM_ChuaDuyetKhongGia
    CHECK (TrangThaiTiepNhan = N'Đã chấp nhận' OR GiaDangBan IS NULL);
GO
CREATE OR ALTER PROCEDURE dbo.sp_TiepNhanPhieuKyGui
    @MaKH INT,
    @MaNV INT,
    @NgayKyGui DATETIME2(0) = NULL,
    @GhiChu NVARCHAR(500) = NULL,
    @SanPham dbo.SanPhamKyGuiType READONLY,
    @MaPKG INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF NOT EXISTS (SELECT 1 FROM dbo.KHACH_HANG WHERE MaKH = @MaKH)
        THROW 51001, N'Khách hàng không tồn tại.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.NHAN_VIEN WHERE MaNV = @MaNV AND TrangThai = N'Đang làm việc')
        THROW 51002, N'Nhân viên không tồn tại hoặc đã nghỉ việc.', 1;
    IF NOT EXISTS (SELECT 1 FROM @SanPham)
        THROW 51003, N'Phiếu ký gửi phải có ít nhất một sản phẩm.', 1;
    IF EXISTS (SELECT 1 FROM @SanPham WHERE LEN(LTRIM(RTRIM(TenSP))) = 0)
        THROW 51004, N'Tên sản phẩm không được rỗng.', 1;
    IF EXISTS (SELECT 1 FROM @SanPham WHERE LEN(LTRIM(RTRIM(TinhTrang))) = 0)
        THROW 51005, N'Tình trạng sản phẩm không được rỗng.', 1;
    IF EXISTS (SELECT 1 FROM @SanPham WHERE TrangThaiTiepNhan <> N'Chờ xử lý')
        THROW 51006, N'Khi tiếp nhận, mọi sản phẩm phải ở trạng thái Chờ xử lý. Xét duyệt sau khi lưu phiếu.', 1;
    IF EXISTS (SELECT 1 FROM @SanPham WHERE MaDM NOT IN (SELECT MaDM FROM dbo.DANH_MUC))
        THROW 51007, N'Danh mục sản phẩm không tồn tại.', 1;
    IF EXISTS (SELECT 1 FROM @SanPham WHERE MaTH IS NOT NULL AND MaTH NOT IN (SELECT MaTH FROM dbo.THUONG_HIEU))
        THROW 51008, N'Thương hiệu sản phẩm không tồn tại.', 1;
    IF EXISTS (SELECT 1 FROM @SanPham WHERE GiaDeXuat < 0)
        THROW 51009, N'Giá đề xuất không được âm.', 1;
    IF EXISTS (SELECT 1 FROM @SanPham WHERE GiaDeXuat > 500000000)
        THROW 51012, N'Giá đề xuất không được vượt quá 500.000.000 đ.', 1;
    IF EXISTS (SELECT 1 FROM @SanPham WHERE GiaDangBan IS NOT NULL)
        THROW 51011, N'Chưa nhập giá đăng bán ở bước tiếp nhận. Giá được chốt khi đăng bán.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;
        INSERT dbo.PHIEU_KY_GUI (MaKH, MaNV, NgayKyGui, TrangThai, GhiChu)
        VALUES (@MaKH, @MaNV, ISNULL(@NgayKyGui, SYSDATETIME()), N'Đang xử lý', @GhiChu);
        SET @MaPKG = CAST(SCOPE_IDENTITY() AS INT);
        INSERT dbo.SAN_PHAM
            (MaPKG, MaDM, MaTH, TenSP, MoTa, KichThuoc, MauSac, ChatLieu, TinhTrang,
             GiaDeXuat, GiaDangBan, TrangThaiTiepNhan, TrangThaiBan, NgayDangBan)
        SELECT @MaPKG, MaDM, MaTH, TenSP, MoTa, KichThuoc, MauSac, ChatLieu, TinhTrang,
               GiaDeXuat, NULL, N'Chờ xử lý', NULL, NULL
        FROM @SanPham;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

-- Xét duyệt không đăng bán và không bắt buộc có giá. Giữ chữ ký cũ để tương thích lời gọi.
CREATE OR ALTER PROCEDURE dbo.sp_DuyetSanPham
    @MaSP INT,
    @KetQua NVARCHAR(20),
    @GiaDangBan DECIMAL(12,0) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @KetQua IS NULL OR @KetQua NOT IN (N'Đã chấp nhận', N'Từ chối')
        THROW 51103, N'Kết quả duyệt chỉ nhận Đã chấp nhận hoặc Từ chối.', 1;
    IF @GiaDangBan IS NOT NULL
        THROW 51104, N'Nhập giá ở bước đăng bán, không nhập giá trong thao tác xét duyệt.', 1;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @TrangThai NVARCHAR(20);
        SELECT @TrangThai = TrangThaiTiepNhan
        FROM dbo.SAN_PHAM WITH (UPDLOCK, HOLDLOCK) WHERE MaSP = @MaSP;
        IF @TrangThai IS NULL
            THROW 51101, N'Sản phẩm không tồn tại.', 1;
        IF @TrangThai <> N'Chờ xử lý'
            THROW 51102, N'Chỉ được duyệt sản phẩm đang chờ xử lý. Hãy làm mới danh sách.', 1;
        IF EXISTS (
            SELECT 1 FROM dbo.CHI_TIET_DON_HANG c
            JOIN dbo.DON_HANG d ON d.MaDH = c.MaDH
            WHERE c.MaSP = @MaSP AND d.TrangThai <> N'Đã hủy'
        )
            THROW 51105, N'Không thể xét duyệt sản phẩm đang thuộc đơn hàng còn hiệu lực.', 1;

        UPDATE dbo.SAN_PHAM
        SET TrangThaiTiepNhan = @KetQua,
            TrangThaiBan = CASE WHEN @KetQua = N'Đã chấp nhận' THEN N'Chưa đăng bán' ELSE NULL END,
            GiaDangBan = NULL,
            NgayDangBan = NULL
        WHERE MaSP = @MaSP;
        -- Trigger TR_SAN_PHAM tổng hợp trạng thái phiếu từ tất cả sản phẩm.
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_DangBanSanPham
    @MaSP INT,
    @GiaDangBan DECIMAL(12,0) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @TiepNhan NVARCHAR(20), @Ban NVARCHAR(20), @GiaHienTai DECIMAL(12,0);
        SELECT @TiepNhan = TrangThaiTiepNhan, @Ban = TrangThaiBan, @GiaHienTai = GiaDangBan
        FROM dbo.SAN_PHAM WITH (UPDLOCK, HOLDLOCK) WHERE MaSP = @MaSP;
        IF @TiepNhan IS NULL
            THROW 51201, N'Sản phẩm không tồn tại.', 1;
        IF @TiepNhan <> N'Đã chấp nhận'
            THROW 51202, N'Chỉ được đăng bán sản phẩm đã được xét duyệt chấp nhận.', 1;
        IF @Ban IS NULL OR @Ban NOT IN (N'Chưa đăng bán', N'Đang bán')
            THROW 51203, N'Chỉ đăng bán hoặc chỉnh giá sản phẩm Chưa đăng bán hoặc Đang bán.', 1;
        SET @GiaDangBan = ISNULL(@GiaDangBan, @GiaHienTai);
        IF @GiaDangBan IS NULL OR @GiaDangBan <= 0
            THROW 51204, N'Phải chốt giá đăng bán lớn hơn 0 trước khi đưa sản phẩm lên bán.', 1;
        IF @GiaDangBan > 500000000
            THROW 51205, N'Giá đăng bán không được vượt quá 500.000.000 đ.', 1;
        UPDATE dbo.SAN_PHAM
        SET GiaDangBan = @GiaDangBan, TrangThaiBan = N'Đang bán', NgayDangBan = ISNULL(NgayDangBan, SYSDATETIME())
        WHERE MaSP = @MaSP;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO
COMMIT TRANSACTION;
GO
