//
//  MoviesListViewModel.swift
//  BanqueMisr-TMDB
//
//  Created by Ahmed Bahgat on 27/03/2024.
//

import Foundation
import Combine

protocol MoviesListViewModelInputs {
  func fetchMoviesList() async throws -> [MovieListItemUI]
  func didLoadNextPage() async throws -> [MovieListItemUI]
  func getSelectedMovieId(at index: Int) -> String
  func fetchPosterImage(posterImgPath:String,width:Int) async throws -> Data
}

enum MoviesListViewModelLoading {
  case fullScreen
  case nextPage
}

protocol MoviesListViewModelOutputs {
  var items:[MovieListItemUI] { get }
  var loading: PassthroughSubject<MoviesListViewModelLoading?,Never> { get }
  var errorMessage:PassthroughSubject<String,Never> { get }
  var isEmpty: Bool { get }
  var emptyDataTitle: String { get }
}

typealias MoviesListViewModel = MoviesListViewModelInputs & MoviesListViewModelOutputs

final class DefaultMoviesListViewModel:MoviesListViewModel {
    //MARK: - Properties
  private let moviesListUseCase:MoviesListUseCase
  private let moviesType:APIEndpoints.MoviesCategoryPath
  private var pages :[MoviesPage] = []
  private var isCurrentlyFetching:Bool = false
  var currentPage:Int = 0
  var totalPageCount:Int = 1
  var hasMorePages:Bool { currentPage < totalPageCount }
  var nextPage: Int { hasMorePages ? currentPage + 1 : currentPage }
    //MARK: - Outputs
  var items: [MovieListItemUI] = []
  var loading: PassthroughSubject<MoviesListViewModelLoading?, Never> = .init()
  var errorMessage: PassthroughSubject<String, Never> = .init()
  var isEmpty: Bool { pages.movies.isEmpty }
  var emptyDataTitle: String { "No available movies"}
    //MARK: - Init
  init(moviesListUseCase:MoviesListUseCase,
       moviesType:APIEndpoints.MoviesCategoryPath) {
    self.moviesListUseCase = moviesListUseCase
    self.moviesType = moviesType
  }
    //MARK: - Private methods
  private func appendPage(_ moviesPage: MoviesPage) {
    currentPage = moviesPage.page
    totalPageCount = moviesPage.totalPages
    removeDuplicatedMovies(moviesPage: moviesPage)
    items = pages.movies.map(MovieListItemUI.init)
  }
  
  private func removeDuplicatedMovies(moviesPage:MoviesPage) {
    pages = pages.filter { $0.page != moviesPage.page }
    var newPages = moviesPage
    var uniqueMovieIDs = Set<String>()
    pages.forEach { uniqueMovieIDs.formUnion($0.movies.map(\.id)) }
    newPages.movies = newPages.movies.filter { !uniqueMovieIDs.contains($0.id) }
    pages.append(newPages)
  }
  
  private func resetPages() {
    currentPage = 0
    totalPageCount = 1
    pages.removeAll()
    items.removeAll()
  }
  
  private func loadMovies(loading:MoviesListViewModelLoading?) async throws -> [MovieListItemUI] {
    do {
      self.loading.send(loading)
      isCurrentlyFetching = true
      let moviesList = try await moviesListUseCase.execute(for: moviesType,
                                                           requestValue: .init(page: nextPage))
      self.loading.send(.none)
      isCurrentlyFetching = false
      appendPage(moviesList)
      return items
    }catch {
      errorMessage.send(error.errorMessage)
      throw error
    }
  }
}
  //MARK: - Inputs
extension DefaultMoviesListViewModel {
  
  func fetchMoviesList() async throws -> [MovieListItemUI] {
    resetPages()
    let loading: MoviesListViewModelLoading? = items.isEmpty ? .fullScreen : .none
    return try await loadMovies(loading: loading)
  }
  
  func didLoadNextPage() async throws -> [MovieListItemUI] {
    guard hasMorePages, !isCurrentlyFetching else { return [] }
    return try await loadMovies(loading: .nextPage)
  }
  
  func getSelectedMovieId(at index: Int) -> String {
    return items[index].id
  }
  
  func fetchPosterImage(posterImgPath: String,width:Int) async throws -> Data {
    let imgData = try await moviesListUseCase.fetchMovieCellImage(
      for: posterImgPath,
      width: width)
    return imgData
    }
}
  //MARK: - Private extension
private extension Array where Element == MoviesPage {
  var movies: [Movie] { flatMap { $0.movies } }
}
