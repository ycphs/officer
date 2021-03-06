ph <- function( left = 0, top = 0, width = 3, height = 3, bg = "transparent", rot = 0){

  if( !is.color( bg ) )
    stop("bg must be a valid color.", call. = FALSE )
  cols <- as.integer( col2rgb(bg, alpha = TRUE)[,1] )

  p_ph(offx=as.integer( left * 914400 ),
    offy = as.integer( top * 914400 ),
    cx = as.integer( width * 914400 ),
    cy = as.integer( height * 914400 ),
    rot = as.integer(-rot * 60000),
    r = cols[1],
    g = cols[2],
    b = cols[3],
    a = cols[4] )
}

#' @rdname ph_empty
#' @export
#' @param left,top location of the new shape on the slide
#' @param width,height shape size in inches
#' @param bg background color
#' @param rot rotation angle
#' @param template_type placeholder template type. If used, the new shape will
#' inherit the style from the placeholder template. If not used, no text
#' property is defined and for example text lists will not be indented.
#' @param template_index placeholder template index (integer). To be used when a placeholder
#' template type is not unique in the current slide, e.g. two placeholders with
#' type 'body'.
#' @examples
#'
#' # demo ph_empty_at ------
#' fileout <- tempfile(fileext = ".pptx")
#' doc <- read_pptx()
#' doc <- add_slide(doc, layout = "Title and Content", master = "Office Theme")
#' doc <- ph_empty_at(x = doc, left = 1, top = 2, width = 5, height = 4)
#'
#' print(doc, target = fileout )
ph_empty_at <- function( x, left, top, width, height, bg = "transparent", rot = 0,
                         template_type = NULL, template_index = 1 ){

  stopifnot( template_type %in% c("ctrTitle", "subTitle", "dt", "ftr", "sldNum", "title", "body") )
  slide <- x$slide$get_slide(x$cursor)

  new_ph <- ph(left = left, top = top, width = width, height = height, rot = rot, bg = bg)
  new_ph <- paste0( pml_with_ns("p:sp"), new_ph,"</p:sp>")
  if( !is.null( template_type ) ){
    xfrm_df <- slide$get_xfrm(type = template_type, index = template_index)
    new_ph <- gsub("<p:ph/>", xfrm_df$ph, new_ph)
  }
  new_node <- as_xml_document(new_ph)

  xml_add_child(xml_find_first(slide$get(), "//p:spTree"), new_node)

  slide$save()
  x$slide$update_slide(x$cursor)
  x
}


#' @export
#' @rdname ph_with_img
#' @param left,top location of the new shape on the slide
#' @param rot rotation angle
#' @examples
#'
#' fileout <- tempfile(fileext = ".pptx")
#' doc <- read_pptx()
#' doc <- add_slide(doc, layout = "Title and Content", master = "Office Theme")
#'
#' img.file <- file.path( R.home("doc"), "html", "logo.jpg" )
#' if( file.exists(img.file) ){
#'   doc <- ph_with_img_at(x = doc, src = img.file, height = 1.06, width = 1.39,
#'     left = 4, top = 4, rot = 45 )
#' }
#'
#' print(doc, target = fileout )
ph_with_img_at <- function( x, src, left, top, width, height, rot = 0 ){

  slide <- x$slide$get_slide(x$cursor)

  new_src <- tempfile( fileext = gsub("(.*)(\\.[a-zA-Z0-0]+)$", "\\2", src) )
  file.copy( src, to = new_src )

  ext_img <- external_img(new_src, width = width, height = height)
  xml_elt <- format(ext_img, type = "pml")

  slide$reference_img(src = new_src, dir_name = file.path(x$package_dir, "ppt/media"))
  xml_elt <- fortify_pml_images(x, xml_elt)

  doc <- as_xml_document(xml_elt)

  node <- xml_find_first( doc, "p:spPr")
  off <- xml_child(node, "a:xfrm/a:off")
  xml_attr( off, "x") <- sprintf( "%.0f", left * 914400 )
  xml_attr( off, "y") <- sprintf( "%.0f", top * 914400 )
  if( rot != 0 ){
    xfrm_node <- xml_child(node, "a:xfrm")
    xml_attr( xfrm_node, "rot") <- sprintf( "%.0f", -rot * 60000 )
  }

  xmlslide <- slide$get()


  xml_add_child(xml_find_first(xmlslide, "p:cSld/p:spTree"), doc)
  slide$save()
  x$slide$update_slide(x$cursor)
  x
}

#' @export
#' @rdname ph_with_table
#' @param left,top location of the new shape on the slide
#' @param width,height shape size in inches
#' @examples
#'
#' library(magrittr)
#'
#' doc <- read_pptx() %>%
#'   add_slide(layout = "Title and Content", master = "Office Theme") %>%
#'   ph_with_table_at(value = mtcars[1:6,],
#'     height = 4, width = 8, left = 4, top = 4,
#'     last_row = FALSE, last_column = FALSE, first_row = TRUE)
#'
#' print(doc, target = "ph_with_table2.pptx")
ph_with_table_at <- function( x, value, left, top, width, height,
                              header = TRUE,
                           first_row = TRUE, first_column = FALSE,
                           last_row = FALSE, last_column = FALSE ){
  stopifnot(is.data.frame(value))

  slide <- x$slide$get_slide(x$cursor)

  xml_elt <- table_shape(x = x, value = value, left = left*914400, top = top*914400, width = width*914400, height = height*914400,
                         first_row = first_row, first_column = first_column,
                         last_row = last_row, last_column = last_column, header = header )

  xml_add_child(xml_find_first(slide$get(), "//p:spTree"), as_xml_document(xml_elt))
  slide$save()
  x$slide$update_slide(x$cursor)
  x
}

#' @export
#' @param left,top location of the new shape on the slide
#' @importFrom grDevices png dev.off
#' @rdname ph_with_gg
ph_with_gg_at <- function( x, value, width, height, left, top, ... ){

  if( !requireNamespace("ggplot2") )
    stop("package ggplot2 is required to use this function")

  stopifnot(inherits(value, "gg") )
  file <- tempfile(fileext = ".png")
  options(bitmapType='cairo')
  png(filename = file, width = width, height = height, units = "in", res = 300, ...)
  print(value)
  dev.off()
  on.exit(unlink(file))
  ph_with_img_at( x, src = file, width = width, height = height, left = left, top = top )
}






#' @export
#' @title add multiple formated paragraphs
#' @description add several formated paragraphs in a new shape in the current slide.
#' @param x rpptx object
#' @param fpars list of \code{\link{fpar}} objects
#' @param fp_pars list of \code{\link{fp_par}} objects. The list can contain
#' NULL to keep defaults.
#' @param left,top location of the new shape on the slide
#' @param width,height shape size in inches
#' @param bg background color
#' @param rot rotation angle
#' @param template_type placeholder template type. If used, the new shape will
#' inherit the style from the placeholder template. If not used, no text
#' property is defined and for example text lists will not be indented.
#' @param template_index placeholder template index (integer). To be used when a placeholder
#' template type is not unique in the current slide, e.g. two placeholders with
#' type 'body'.
#' @examples
#'
#' fileout <- tempfile(fileext = ".pptx")
#' doc <- read_pptx()
#' doc <- add_slide(doc, layout = "Title and Content",
#'   master = "Office Theme")
#'
#' bold_face <- shortcuts$fp_bold(font.size = 0)
#' bold_redface <- update(bold_face, color = "red")
#'
#' fpar_1 <- fpar(
#'   ftext("Hello ", prop = bold_face), ftext("World", prop = bold_redface ),
#'   ftext(", \r\nhow are you?", prop = bold_face ) )
#'
#' fpar_2 <- fpar(
#'   ftext("Hello ", prop = bold_face), ftext("World", prop = bold_redface ),
#'   ftext(", \r\nhow are you again?", prop = bold_face ) )
#'
#' doc <- ph_with_fpars_at(x = doc, fpars = list(fpar_1, fpar_2),
#'   fp_pars = list(NULL, fp_par(text.align = "center")),
#'   left = 1, top = 2, width = 7, height = 4)
#' doc <- ph_with_fpars_at(x = doc, fpars = list(fpar_1, fpar_2),
#'   template_type = "body", template_index = 1,
#'   left = 4, top = 5, width = 4, height = 3)
#'
#' print(doc, target = fileout )
ph_with_fpars_at <- function( x, fpars = list(), fp_pars = list(),
                         left, top, width, height, bg = "transparent", rot = 0,
                         template_type = NULL, template_index = 1 ){

  stopifnot( template_type %in% c("ctrTitle", "subTitle", "dt", "ftr", "sldNum", "title", "body") )
  slide <- x$slide$get_slide(x$cursor)

  new_ph <- ph(left = left, top = top, width = width, height = height, rot = rot, bg = bg)
  new_ph <- paste0( pml_with_ns("p:sp"), new_ph,"</p:sp>")
  if( !is.null( template_type ) ){
    xfrm_df <- slide$get_xfrm(type = template_type, index = template_index)
    new_ph <- gsub("<p:ph/>", xfrm_df$ph, new_ph)
  }


  new_node <- as_xml_document(new_ph)

  if( length(fp_pars) < 1 )
    fp_pars <- lapply(fpars, function(x) NULL )
  if( length(fp_pars) != length(fpars) )
    stop("fp_pars and fpars should have the same length")

  p_ <- mapply(
    function(fpar, fp_par) {
      if( !is.null(fp_par) ) {
        fpar <- update(fpar, fp_p = fp_par)
      }
      format( fpar, type = "pml")
    },
    fpar = fpars, fp_par = fp_pars, SIMPLIFY = FALSE )
  p_ <- do.call( paste0, p_ )

  simple_shape <- paste0( pml_with_ns("p:txBody"),
                          "<a:bodyPr/><a:lstStyle/>",
                          p_, "</p:txBody>")
  xml_add_child(new_node, as_xml_document(simple_shape) )


  xml_add_child(xml_find_first(slide$get(), "//p:spTree"), new_node)
  slide$save()
  x$slide$update_slide(x$cursor)
  x
}

